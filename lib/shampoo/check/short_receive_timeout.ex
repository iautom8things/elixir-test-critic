defmodule Shampoo.Check.ShortReceiveTimeout do
  alias Shampoo.Check.Source

  @default_macros [
    :assert_receive,
    :assert_push,
    :assert_reply,
    :assert_broadcast,
    :assert_redirect,
    :assert_patch,
    :render_async
  ]

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [min_timeout: 500, macros: @default_macros, require_configured_default: true],
    explanations: [
      check: """
      ETC-CORE-012: Give a cross-process assertion enough time on a loaded
      runner. Allow at least the configured minimum on explicit waits and in
      the test helper's assert_receive_timeout. Use assert_received when
      delivery is already synchronized.
      """,
      params: [
        min_timeout: "Minimum literal timeout in milliseconds. Defaults to 500.",
        macros:
          "Wait functions and macros to check. Custom names take their timeout as the last argument.",
        require_configured_default:
          "Require assert_receive_timeout in test/test_helper.exs. Defaults to true."
      ]
    ]

  use Shampoo.Check.Options,
    min_timeout: :nonnegative_integer,
    macros: {:list, :atom},
    require_configured_default: :boolean

  defp analyze(source_file, params, options) do
    issue_meta = IssueMeta.for(source_file, params)

    cond do
      options.require_configured_default and Source.test_helper?(source_file) ->
        helper_issues(source_file, issue_meta, options.min_timeout)

      Source.test_file?(source_file) ->
        issues(source_file, issue_meta, options)

      true ->
        []
    end
  end

  defp issues(source_file, issue_meta, %{min_timeout: min_timeout, macros: macros}) do
    Source.reduce(source_file, [], fn node, scope, issues ->
      call = Source.call(node, scope)

      if negative_live_navigation?(call, scope),
        do: {:skip, issues},
        else: collect_timeout(call, macros, min_timeout, issue_meta, issues)
    end)
  end

  defp collect_timeout({_, name, meta, args}, macros, min_timeout, issue_meta, issues) do
    with true <- name in macros and not String.starts_with?(Atom.to_string(name), "refute_"),
         timeout when is_integer(timeout) and timeout < min_timeout <-
           literal_integer(timeout(name, args)) do
      [timeout_issue(issue_meta, name, meta, min_timeout, timeout) | issues]
    else
      _ -> issues
    end
  end

  defp collect_timeout(_call, _macros, _min_timeout, _issue_meta, issues), do: issues

  # A zero-timeout navigation assertion expected to raise is a negative check.
  defp negative_live_navigation?({module, :assert_raise, _, [exception | args]}, scope)
       when module in [:local, [:ExUnit, :Assertions]] do
    Source.module_name(exception, scope) == [:ArgumentError] and
      zero_navigation_callback?(List.last(args), scope)
  end

  defp negative_live_navigation?(_call, _scope), do: false

  defp zero_navigation_callback?({:fn, _, [{:->, _, [[], body]}]}, scope) do
    case Source.call(body, scope) do
      {module, name, _, args}
      when module in [:local, [:Phoenix, :LiveViewTest]] and
             name in [:assert_patch, :assert_redirect] ->
        timeout(name, args) == 0

      _ ->
        false
    end
  end

  defp zero_navigation_callback?(_callback, _scope), do: false

  defp timeout(:assert_receive, [_, timeout]), do: timeout
  defp timeout(:assert_receive, [_, timeout, _message]), do: timeout
  defp timeout(:assert_reply, [_, _, _, timeout]), do: timeout
  defp timeout(name, [_, _, timeout]) when name in [:assert_push, :assert_broadcast], do: timeout
  defp timeout(name, [_, _, timeout]) when name in [:assert_patch, :assert_redirect], do: timeout

  defp timeout(name, [_, timeout]) when name in [:assert_patch, :assert_redirect, :render_async],
    do: timeout

  defp timeout(name, [_, _ | _] = args) when name not in @default_macros, do: List.last(args)
  defp timeout(_name, _args), do: nil

  defp literal_integer({:-, _, [value]}) when is_integer(value), do: -value
  defp literal_integer({:+, _, [value]}) when is_integer(value), do: value
  defp literal_integer(value) when is_integer(value), do: value
  defp literal_integer(_value), do: nil

  defp timeout_issue(issue_meta, name, meta, min_timeout, timeout) do
    message = "Allow at least #{min_timeout} ms for a cross-process wait."

    message =
      if name == :assert_receive and timeout == 0,
        do: message <> " If delivery is already synchronized, use assert_received.",
        else: message

    format_issue(issue_meta,
      message: message,
      trigger: Atom.to_string(name),
      line_no: meta[:line],
      column: meta[:column]
    )
  end

  defp helper_issues(source_file, issue_meta, min_timeout) do
    {calls, binding_counts} = Source.reduce(source_file, {[], %{}}, &collect_helper_facts/3)
    bindings = option_bindings(source_file, binding_counts)
    calls = Enum.sort_by(calls, fn {_name, meta, _args} -> position(meta) end, :desc)

    case Enum.find_value(calls, &configured_timeout(&1, bindings)) do
      :unknown ->
        []

      nil ->
        [default_issue(issue_meta, min_timeout, default_location(List.last(calls), source_file))]

      {value, location} ->
        if acceptable_default?(value, min_timeout),
          do: [],
          else: [default_issue(issue_meta, min_timeout, location)]
    end
  end

  defp option_bindings(source_file, binding_counts) do
    assignments =
      source_file
      |> SourceFile.ast()
      |> Source.expressions()

    for {:=, meta, [{name, _, context}, value]} <- assignments,
        is_atom(name) and is_atom(context),
        key = {name, context},
        binding_counts[key] == 1,
        into: %{} do
      {key, {position(meta), value}}
    end
  end

  defp collect_helper_facts({kind, _, _}, _scope, facts)
       when kind in [:defmodule, :def, :defp, :defmacro, :defmacrop, :fn],
       do: {:skip, facts}

  defp collect_helper_facts({operator, _, [pattern, _]}, _scope, {calls, counts})
       when operator in [:=, :<-, :->] do
    {_, counts} = Macro.prewalk(pattern, counts, &count_binding/2)
    {calls, counts}
  end

  defp collect_helper_facts(node, scope, {calls, counts} = facts) do
    case Source.call(node, scope) do
      {[:ExUnit], name, meta, args} when name in [:start, :configure] ->
        {[{name, meta, args} | calls], counts}

      _ ->
        facts
    end
  end

  defp count_binding({name, _, context} = variable, counts)
       when is_atom(name) and is_atom(context),
       do: {variable, Map.update(counts, {name, context}, 1, &(&1 + 1))}

  defp count_binding(node, counts), do: {node, counts}

  defp configured_timeout({name, meta, [argument]}, bindings) do
    with {:ok, options} <- resolve_options(argument, bindings, position(meta)),
         {:ok, value} <- Keyword.fetch(options, :assert_receive_timeout) do
      {value, call_location(name, meta)}
    else
      :error -> nil
      :unknown -> :unknown
    end
  end

  defp configured_timeout(_call, _bindings), do: nil

  defp resolve_options({name, _, context}, bindings, call_position)
       when is_atom(name) and is_atom(context) do
    case Map.fetch(bindings, {name, context}) do
      {:ok, {binding_position, value}} when binding_position < call_position ->
        literal_options(value)

      _ ->
        :unknown
    end
  end

  defp resolve_options(argument, _bindings, _call_position), do: literal_options(argument)

  defp literal_options(list) when is_list(list) do
    if Keyword.keyword?(list), do: {:ok, list}, else: :unknown
  end

  defp literal_options({:++, _, [left, right]}) do
    with {:ok, left} <- literal_options(left),
         {:ok, right} <- literal_options(right) do
      {:ok, left ++ right}
    end
  end

  defp literal_options(_argument), do: :unknown

  defp position(meta), do: {meta[:line], meta[:column]}

  defp acceptable_default?(value, min_timeout) do
    case literal_integer(value) do
      nil -> not literal?(value)
      integer -> integer >= min_timeout
    end
  end

  defp literal?({sign, _, [number]}) when sign in [:+, :-] and is_number(number), do: true
  defp literal?(value), do: Macro.quoted_literal?(value)

  defp default_location({name, meta, _args}, _source_file), do: call_location(name, meta)
  defp default_location(nil, source_file), do: [line_no: first_code_line(source_file)]

  defp call_location(name, meta) do
    [trigger: Atom.to_string(name), line_no: meta[:line], column: meta[:column]]
  end

  defp default_issue(issue_meta, min_timeout, location) do
    message =
      "Set assert_receive_timeout to at least #{min_timeout} ms in ExUnit.configure/1 or ExUnit.start/1."

    format_issue(issue_meta, [message: message] ++ location)
  end

  defp first_code_line(source_file) do
    Enum.find_value(SourceFile.lines(source_file), 1, fn {line, text} ->
      text = String.trim(text)
      if text != "" and not String.starts_with?(text, "#"), do: line
    end)
  end
end
