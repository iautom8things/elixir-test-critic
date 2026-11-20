defmodule TestCritic.Credo.Check.ShortReceiveTimeout do
  alias TestCritic.Credo.Source

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
    param_defaults: [min_timeout: 500, macros: @default_macros, require_configured_default: false],
    explanations: [
      check: """
      ETC-CORE-012: Give a cross-process assertion enough time on a loaded
      runner. Use a suite-wide assert_receive_timeout or allow at least the
      configured minimum on an explicit wait. Use assert_received when
      delivery is already synchronized.
      """,
      params: [
        min_timeout: "Minimum literal timeout in milliseconds. Defaults to 500.",
        macros:
          "Wait functions and macros to check. Custom names take their timeout as the last argument.",
        require_configured_default:
          "Also require assert_receive_timeout in test/test_helper.exs. Defaults to false."
      ]
    ]

  @impl Credo.Check
  def run(source_file, params) do
    cond do
      Source.test_helper?(source_file) -> helper_issues(source_file, params)
      Source.test_file?(source_file) -> issues(source_file, params)
      true -> []
    end
  end

  defp issues(source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    min_timeout = Params.get(params, :min_timeout, __MODULE__)
    macros = Params.get(params, :macros, __MODULE__)

    Source.reduce(source_file, [], fn node, scope, issues ->
      call = Source.call(node, scope)

      if negative_live_navigation?(call, scope),
        do: {:skip, issues},
        else: collect_timeout(call, macros, min_timeout, issue_meta, issues)
    end)
  end

  defp collect_timeout({_, name, meta, args}, macros, min_timeout, issue_meta, issues) do
    if name in macros and not String.starts_with?(Atom.to_string(name), "refute_") and
         short?(timeout(name, args), min_timeout) do
      [timeout_issue(issue_meta, name, meta, min_timeout) | issues]
    else
      issues
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

  defp short?({:-, _, [value]}, min_timeout) when is_integer(value), do: -value < min_timeout
  defp short?({:+, _, [value]}, min_timeout) when is_integer(value), do: value < min_timeout
  defp short?(value, min_timeout), do: is_integer(value) and value < min_timeout

  defp timeout_issue(issue_meta, name, meta, min_timeout) do
    format_issue(issue_meta,
      message:
        "Allow at least #{min_timeout} ms for a cross-process wait or use the suite default.",
      trigger: Atom.to_string(name),
      line_no: meta[:line],
      column: meta[:column]
    )
  end

  defp helper_issues(source_file, params) do
    if Params.get(params, :require_configured_default, __MODULE__) do
      check_suite_default(source_file, params)
    else
      []
    end
  end

  defp check_suite_default(source_file, params) do
    calls = Source.reduce(source_file, [], &collect_exunit_call/3)

    if Enum.any?(calls, &configures_timeout?/1),
      do: [],
      else: [missing_default(source_file, params, calls)]
  end

  defp collect_exunit_call({:defmodule, _, _}, _scope, calls), do: {:skip, calls}

  defp collect_exunit_call(node, scope, calls) do
    case Source.call(node, scope) do
      {[:ExUnit], name, meta, args} when name in [:start, :configure] ->
        [{name, meta, args} | calls]

      _ ->
        calls
    end
  end

  defp configures_timeout?({_name, _meta, [options]}) when is_list(options),
    do: Keyword.keyword?(options) and Keyword.has_key?(options, :assert_receive_timeout)

  defp configures_timeout?(_call), do: false

  defp missing_default(source_file, params, calls) do
    location =
      case Enum.min_by(calls, fn {_name, meta, _args} -> meta[:line] end, fn -> nil end) do
        {name, meta, _args} ->
          [trigger: Atom.to_string(name), line_no: meta[:line], column: meta[:column]]

        nil ->
          [line_no: first_code_line(source_file)]
      end

    format_issue(
      IssueMeta.for(source_file, params),
      [message: "Set assert_receive_timeout in ExUnit.configure/1 or ExUnit.start/1."] ++ location
    )
  end

  defp first_code_line(source_file) do
    Enum.find_value(SourceFile.lines(source_file), 1, fn {line, text} ->
      text = String.trim(text)
      if text != "" and not String.starts_with?(text, "#"), do: line
    end)
  end
end
