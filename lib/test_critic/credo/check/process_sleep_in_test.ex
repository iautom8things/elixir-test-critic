defmodule TestCritic.Credo.Check.ProcessSleepInTest do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [excluded_paths: ["test/support"]],
    explanations: [
      check: """
      ETC-CORE-005: Wait on a message, monitor the process, or poll with a deadline.
      For a deliberate sleep, use a Credo disable comment and write the reason.
      """,
      params: [excluded_paths: "Test paths to skip, relative to the Mix project."]
    ]

  @impl Credo.Check
  def run(source_file, params) do
    excluded_paths = Params.get(params, :excluded_paths, __MODULE__)

    if test_source?(source_file) and not excluded?(source_file, excluded_paths) do
      issue_meta = IssueMeta.for(source_file, params)
      Source.reduce(source_file, [], &find_sleep(&1, &2, &3, issue_meta))
    else
      []
    end
  end

  defp find_sleep(node, scope, issues, issue_meta) do
    case Source.call(node, scope) do
      {module, :sleep, meta, [_duration]} when module in [[:Process], :timer] ->
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
