defmodule TestCritic.Credo.Check.NamedProcessOutsideSupervision do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      ETC-CORE-006: Start named processes with start_supervised/2 or
      start_supervised!/2. ExUnit waits for the process to stop before
      the next test can try to register the same name.
      """
    ]

  @impl Credo.Check
  def run(source_file, params) do
    if Source.test_file?(source_file), do: issues(source_file, params), else: []
  end

  defp issues(source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    Source.reduce(source_file, [], &find_start(&1, &2, &3, issue_meta))
  end

  # The caller decides which supervisor owns a child started by an entry point.
  defp find_start({kind, _, [head, _body]}, _scope, issues, _issue_meta)
       when kind in [:def, :defp] and elem(head, 0) in [:start, :start_link],
       do: {:skip, issues}

  defp find_start({kind, _, [{:when, _, [head | _]}, _body]}, _scope, issues, _issue_meta)
       when kind in [:def, :defp] and elem(head, 0) in [:start, :start_link],
       do: {:skip, issues}

  defp find_start(node, scope, issues, issue_meta) do
    case Source.call(node, scope) do
      {module, name, _, [child | options]}
      when module in [:local, [:ExUnit, :Callbacks]] and
             name in [:start_supervised, :start_supervised!] ->
        nested = nested_start_arguments(child) ++ options
        {:skip, Source.reduce(nested, scope, issues, &find_start(&1, &2, &3, issue_meta))}

      {module, :assert, _, [{operator, _, [left, right]} | message]}
      when module in [:local, [:ExUnit, :Assertions]] and operator in [:==, :===, :=] ->
        negative_start(left, right, message, scope, issues, issue_meta)

      {module, name, meta, args}
      when name in [:start, :start_link] and (is_list(module) or module == :__MODULE__) ->
        report_start(module, name, meta, args, issues, issue_meta)

      _ ->
        issues
    end
  end

  defp report_start(module, name, meta, args, issues, issue_meta) do
    if named?(module, args) do
      issue =
        format_issue(issue_meta,
          message:
            "Start named processes with start_supervised or start_supervised! so ExUnit waits for cleanup.",
          trigger: Atom.to_string(name),
          line_no: meta[:line],
          column: meta[:column]
        )

      [issue | issues]
    else
      issues
    end
  end

  defp negative_start(left, right, message, scope, issues, issue_meta) do
    cond do
      left == :ignore -> skip_ignored_start(right, message, scope, issues, issue_meta)
      right == :ignore -> skip_ignored_start(left, message, scope, issues, issue_meta)
      true -> issues
    end
  end

  defp skip_ignored_start(child, message, scope, issues, issue_meta) do
    nested = nested_start_arguments(child) ++ message
    {:skip, Source.reduce(nested, scope, issues, &find_start(&1, &2, &3, issue_meta))}
  end

  defp nested_start_arguments({{:., _, [_, name]}, _, args})
       when name in [:start, :start_link] and is_list(args),
       do: args

  defp nested_start_arguments(child), do: [child]

  defp named?([:GenServer], [_, _]), do: false
  defp named?([:Supervisor], [{:__aliases__, _, _}, _]), do: false

  defp named?([:Supervisor], [_, options]) when is_list(options) do
    Keyword.keyword?(options) and Keyword.has_key?(options, :strategy) and named_options?(options)
  end

  defp named?([:Agent], [_, _, _]), do: false
  defp named?([:Task], [_, _, _]), do: false
  defp named?(_module, args), do: named_options?(List.last(args))

  defp named_options?(options) when is_list(options),
    do: Keyword.keyword?(options) and Keyword.get(options, :name) != nil

  defp named_options?(_options), do: false
end
