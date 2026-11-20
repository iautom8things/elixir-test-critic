defmodule TestCritic.Credo.Check.ProcessSleepInTest do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [scope: :test_flow, excluded_paths: ["test/support"]],
    explanations: [
      check: """
      ETC-CORE-005: Wait on a message, monitor the process, or poll with a deadline.
      The default checks sleep statements in tests and setup blocks, including
      their inline branches. Use scope: :all to check sleeps in helpers and
      callbacks too.
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
    {:local, :setup},
    {:local, :setup_all},
    {[:ExUnit, :Case], :test},
    {[:ExUnit, :Callbacks], :setup},
    {[:ExUnit, :Callbacks], :setup_all}
  ]
  @inline_blocks [:case, :cond, :for, :if, :receive, :try, :unless, :with]
  @branch_keys [:do, :else, :rescue, :catch, :after]

  @impl Credo.Check
  def run(source_file, params) do
    excluded_paths = Params.get(params, :excluded_paths, __MODULE__)

    if test_source?(source_file) and not excluded?(source_file, excluded_paths) do
      issue_meta = IssueMeta.for(source_file, params)

      case Params.get(params, :scope, __MODULE__) do
        :test_flow -> Source.reduce(source_file, [], &find_test_block(&1, &2, &3, issue_meta))
        :all -> Source.reduce(source_file, [], &find_sleep(&1, &2, &3, issue_meta))
      end
    else
      []
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

  defp check_statements(body, scope, issues, issue_meta) do
    Source.reduce_statements(body, scope, issues, &check_statement(&1, &2, &3, issue_meta))
  end

  defp check_statement({form, _, args}, scope, issues, issue_meta)
       when form in @inline_blocks and is_list(args) do
    branches =
      for {key, branch} <- List.wrap(List.last(args)), key in @branch_keys, do: branch

    Enum.reduce(branches, issues, &check_branch(&1, scope, &2, issue_meta))
  end

  defp check_statement(node, scope, issues, issue_meta),
    do: find_sleep(node, scope, issues, issue_meta)

  defp check_branch([{:->, _, _} | _] = clauses, scope, issues, issue_meta) do
    Enum.reduce(clauses, issues, fn {:->, _, [_, body]}, issues ->
      check_statements(body, scope, issues, issue_meta)
    end)
  end

  defp check_branch(body, scope, issues, issue_meta),
    do: check_statements(body, scope, issues, issue_meta)

  defp find_sleep(node, scope, issues, issue_meta) do
    case Source.call(node, scope) do
      {module, :sleep, meta, [duration]}
      when module in [[:Process], :timer] and duration != :infinity ->
        issue =
          format_issue(issue_meta,
            message:
              "Wait on a message, monitor the process, or poll with a deadline. " <>
                "For a deliberate sleep, use a Credo disable comment and include the reason.",
            trigger: "sleep",
            line_no: meta[:line],
            column: meta[:column]
          )

        [issue | issues]

      _ ->
        issues
    end
  end

  defp test_source?(source), do: Source.test_file?(source) or Source.test_support_file?(source)

  defp excluded?(source, paths), do: Enum.any?(paths, &Source.test_path_matches?(source, &1))
end
