defmodule TestCritic.Credo.Check.ProcessSleepInTest do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [scope: :test_flow, excluded_paths: ["test/support"]],
    explanations: [
      check: """
      ETC-CORE-005: Wait on a message, monitor the process, or poll with a deadline.
      The default checks sleep statements in test, feature, property and setup
      blocks, including their inline branches and helpers that only sleep. Use
      scope: :all to include sleeps in other helpers and callbacks.
      For a deliberate sleep, use a Credo disable comment and write the reason.
      A literal :infinity is treated as a deliberate block.
      """,
      params: [
        scope: ":test_flow checks test and setup statements. :all checks every finite sleep.",
        excluded_paths: "Test paths to skip, relative to the Mix project."
      ]
    ]

  @test_blocks [
    {:local, :test},
    {:local, :feature},
    {:local, :property},
    {:local, :setup},
    {:local, :setup_all},
    {[:Wallaby, :Feature], :feature},
    {[:ExUnitProperties], :property},
    {[:ExUnit, :Case], :test},
    {[:ExUnit, :Callbacks], :setup},
    {[:ExUnit, :Callbacks], :setup_all}
  ]
  @inline_blocks [:case, :cond, :for, :if, :receive, :try, :unless, :with]
  @branch_keys [:do, :else, :rescue, :catch, :after]

  use TestCritic.Credo.Options,
    scope: {:one_of, [:test_flow, :all]},
    excluded_paths: {:list, :path}

  defp analyze(source_file, params, options) do
    if test_source?(source_file) and not excluded?(source_file, options.excluded_paths) do
      issue_meta = IssueMeta.for(source_file, params)

      case options.scope do
        :test_flow -> Source.reduce(source_file, [], &find_test_block(&1, &2, &3, issue_meta))
        :all -> Source.reduce(source_file, [], &find_sleep(&1, &2, &3, issue_meta))
      end
    else
      []
    end
  end

  defp find_test_block({kind, _, [_, [do: body]]}, scope, issues, issue_meta)
       when kind in [:def, :defp] do
    case Source.expressions(body) do
      [statement] -> {:skip, check_helper_statement(statement, scope, issues, issue_meta)}
      [statement, :ok] -> {:skip, check_helper_statement(statement, scope, issues, issue_meta)}
      _ -> {:skip, issues}
    end
  end

  defp find_test_block({kind, _, _}, _scope, issues, _issue_meta)
       when kind in [:fn, :def, :defp, :defmacro, :defmacrop],
       do: {:skip, issues}

  defp find_test_block(node, scope, issues, issue_meta) do
    with {module, name, _, args} when {module, name} in @test_blocks <- Source.call(node, scope),
         [do: body] <- List.last(args) do
      {:skip, check_statements(body, scope, issues, issue_meta)}
    else
      _ -> issues
    end
  end

  defp check_helper_statement(statement, scope, issues, issue_meta) do
    Source.reduce_statements(statement, scope, issues, fn node, scope, issues ->
      if sleep_only_helper?(Source.call(node, scope)),
        do: find_sleep(node, scope, issues, issue_meta),
        else: issues
    end)
  end

  defp sleep_only_helper?({:local, :receive, _, [branches]}) when is_list(branches) do
    with true <- Keyword.keyword?(branches),
         [{:->, _, [_, body]}] <- Keyword.get(branches, :after) do
      Macro.quoted_literal?(body)
    else
      _ -> false
    end
  end

  defp sleep_only_helper?(_call), do: true

  defp check_statements(body, scope, issues, issue_meta) do
    Source.reduce_statements(body, scope, issues, &check_statement(&1, &2, &3, issue_meta))
  end

  defp check_statement({form, _, args} = node, scope, issues, issue_meta)
       when form in @inline_blocks and is_list(args) do
    branches =
      for {key, branch} <- List.wrap(List.last(args)), key in @branch_keys, do: branch

    issues = find_sleep(node, scope, issues, issue_meta)
    Enum.reduce(branches, issues, &check_branch(&1, scope, &2, issue_meta))
  end

  defp check_statement(node, scope, issues, issue_meta) do
    case Source.call(node, scope) do
      {:local, :=, _, [_, right]} ->
        check_sleep_statement(right, scope, issues, issue_meta)

      {module, :assert, _, [{:=, _, [_, right]} | _message]}
      when module in [:local, [:ExUnit, :Assertions]] ->
        check_sleep_statement(right, scope, issues, issue_meta)

      _ ->
        find_sleep(node, scope, issues, issue_meta)
    end
  end

  defp check_sleep_statement(node, scope, issues, issue_meta) do
    Source.reduce_statements(node, scope, issues, &find_sleep(&1, &2, &3, issue_meta))
  end

  defp check_branch([{:->, _, _} | _] = clauses, scope, issues, issue_meta) do
    Enum.reduce(clauses, issues, fn
      {:->, _, [_, body]}, issues -> check_statements(body, scope, issues, issue_meta)
      _clause, issues -> issues
    end)
  end

  defp check_branch(body, scope, issues, issue_meta),
    do: check_statements(body, scope, issues, issue_meta)

  defp find_sleep(node, scope, issues, issue_meta) do
    case sleep_call(Source.call(node, scope), scope) do
      {name, meta} ->
        issue =
          format_issue(issue_meta,
            message:
              "Wait on a message, monitor the process, or poll with a deadline. " <>
                "For a deliberate sleep, use a Credo disable comment and include the reason.",
            trigger: Atom.to_string(name),
            line_no: meta[:line],
            column: meta[:column]
          )

        [issue | issues]

      _ ->
        issues
    end
  end

  defp sleep_call({module, :sleep, meta, [duration]}, _scope)
       when module in [[:Process], :timer] and duration != :infinity,
       do: {:sleep, meta}

  defp sleep_call({:local, :sleep, meta, [duration]}, scope) when duration != :infinity do
    if Enum.any?([[:Process], :timer], &Source.imported?(scope, &1, :sleep, 1)),
      do: {:sleep, meta}
  end

  defp sleep_call({:local, :receive, meta, [branches]}, _scope) when is_list(branches) do
    if Keyword.keyword?(branches) and empty_receive?(branches[:do]) and
         finite_after?(branches[:after]),
       do: {:receive, meta}
  end

  defp sleep_call(_call, _scope), do: nil

  defp empty_receive?(body), do: is_nil(body) or match?({:__block__, _, []}, body)

  defp finite_after?([{:->, _, [[timeout], _]}]), do: timeout != :infinity
  defp finite_after?(_after), do: false

  defp test_source?(source), do: Source.test_file?(source) or Source.test_support_file?(source)

  defp excluded?(source, paths), do: Enum.any?(paths, &Source.test_path_matches?(source, &1))
end
