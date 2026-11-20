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
    {:persistent_term, :put},
    {:persistent_term, :erase}
  ]
  @imported_writes [
    {[:Application], :put_env, [3, 4]},
    {[:Application], :put_all_env, [1, 2]},
    {[:Application], :delete_env, [2, 3]},
    {[:System], :put_env, [1, 2]},
    {[:System], :delete_env, [1]}
  ]

  @impl Credo.Check
  def run(source_file, params) do
    if Source.test_file?(source_file), do: issues(source_file, params), else: []
  end

  defp issues(source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Source.reduce(source_file, [], fn
      {:defmodule, _, [_, [do: body]]}, scope, issues ->
        if async_module?(body) do
          Source.reduce(body, scope, issues, &find_write(&1, &2, &3, issue_meta))
        else
          issues
        end

      _node, _scope, issues ->
        issues
    end)
  end

  defp async_module?(body) do
    body
    |> Source.expressions()
    |> Enum.reduce_while(%{}, fn
      {:@, _, [{name, _, [value]}]}, attrs when is_atom(name) ->
        {:cont, Map.put(attrs, name, value)}

      {:use, _, [_, options]}, attrs when is_list(options) ->
        if Keyword.keyword?(options) and async?(Keyword.get(options, :async), attrs),
          do: {:halt, true},
          else: {:cont, attrs}

      _node, attrs ->
        {:cont, attrs}
    end)
    |> Kernel.==(true)
  end

  defp async?(true, _attrs), do: true

  defp async?({:@, _, [{name, _, context}]}, attrs) when is_atom(name) and is_atom(context),
    do: Map.get(attrs, name) == true

  defp async?(_value, _attrs), do: false

  defp find_write({:defmodule, _, _}, _scope, issues, _issue_meta), do: {:skip, issues}

  defp find_write(node, scope, issues, issue_meta) do
    case global_write(Source.call(node, scope), scope) do
      {name, meta} ->
        issue =
          format_issue(issue_meta,
            message: advice(name),
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

  defp global_write({[:Mox], :set_mox_global, meta, _args}, _scope),
    do: {:set_mox_global, meta}

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

  defp global_write({:ets, :new, meta, [name, options]}, _scope)
       when is_atom(name) and is_list(options) do
    if :named_table in options, do: {:new, meta}
  end

  defp global_write({:local, name, meta, args}, scope) do
    arity = length(args)

    if Enum.any?(@imported_writes, fn {module, function, arities} ->
         name == function and arity in arities and Source.imported?(scope, module, name, arity)
       end),
       do: {name, meta}
  end

  defp global_write(_call, _scope), do: nil

  defp global_setup?(:set_mox_global, _scope), do: true

  defp global_setup?({module, :set_mox_global}, scope),
    do: Source.module_name(module, scope) == [:Mox]

  defp global_setup?(_callback, _scope), do: false

  defp advice(:new) do
    "Use an unnamed ETS table or a unique name per test. Keep tests that share a fixed name async: false."
  end

  defp advice(name) when name in [:set_mox_global, :setup] do
    "Keep Mox in private mode and grant access with Mox.allow/3. Use async: false when global mode is necessary."
  end

  defp advice(_name) do
    "Pass the value in, or make the module async: false with a comment naming the state."
  end
end
