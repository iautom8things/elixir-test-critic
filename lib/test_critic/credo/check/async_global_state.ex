defmodule TestCritic.Credo.Check.AsyncGlobalState do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      ETC-ISO-001 and ETC-ISO-003: Async tests share VM-wide state.
      Pass the value in, or make the module async: false with a comment naming the state.
      """
    ]

  @writes [
    {[:Application], :put_env},
    {[:Application], :put_all_env},
    {[:Application], :delete_env},
    {[:System], :put_env},
    {[:System], :delete_env},
    {[:Logger], :configure},
    {[:Logger], :put_module_level},
    {[:Mox], :set_mox_global},
    {:persistent_term, :put},
    {:persistent_term, :erase}
  ]

  @impl Credo.Check
  def run(source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Source.reduce(source_file, [], fn
      {:defmodule, _, [_, [do: body]]}, scope, issues ->
        if Enum.any?(Source.expressions(body), &async_use?/1) do
          Source.reduce(body, scope, issues, &find_write(&1, &2, &3, issue_meta))
        else
          issues
        end

      _node, _scope, issues ->
        issues
    end)
  end

  defp async_use?({:use, _, [_, options]}) when is_list(options),
    do: Keyword.keyword?(options) and Keyword.get(options, :async) == true

  defp async_use?(_node), do: false

  defp find_write({:defmodule, _, _}, _scope, issues, _issue_meta), do: {:skip, issues}

  defp find_write(node, scope, issues, issue_meta) do
    case global_write(Source.call(node, scope), scope) do
      {name, meta} ->
        issue =
          format_issue(issue_meta,
            message:
              "Pass the value in, or make the module async: false with a comment naming the state.",
            trigger: Atom.to_string(name),
            line_no: meta[:line],
            column: meta[:column]
          )

        [issue | issues]

      nil ->
        issues
    end
  end

  defp global_write({module, name, meta, _}, _scope) when {module, name} in @writes,
    do: {name, meta}

  defp global_write({:local, :set_mox_global, meta, args}, scope) do
    if Source.imported?(scope, [:Mox], :set_mox_global, length(args)), do: {:set_mox_global, meta}
  end

  defp global_write({:local, :setup, meta, [callback]}, _scope)
       when callback == :set_mox_global,
       do: {:setup, meta}

  defp global_write({:local, :setup, meta, [{_, :set_mox_global} = callback]}, scope) do
    if global_setup?(callback, scope), do: {:setup, meta}
  end

  defp global_write({:local, :setup, meta, [callbacks]}, scope) when is_list(callbacks) do
    if Enum.any?(callbacks, &global_setup?(&1, scope)), do: {:setup, meta}
  end

  defp global_write({:ets, :new, meta, [_, options]}, _scope) when is_list(options) do
    if :named_table in options, do: {:new, meta}
  end

  defp global_write(_call, _scope), do: nil

  defp global_setup?(:set_mox_global, _scope), do: true

  defp global_setup?({module, :set_mox_global}, scope),
    do: Source.module_name(module, scope) == [:Mox]

  defp global_setup?(_callback, _scope), do: false
end
