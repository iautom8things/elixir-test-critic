defmodule TestCritic.Credo.Check.NondeterministicConfig do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      ETC-ORG-006: Keep build-time configuration stable across reads.
      Move clock, random and unique value generation to config/runtime.exs
      or to the code that needs the value. Changes to build-time config can
      invalidate Mix's compilation cache.
      """
    ]

  @system_functions [:os_time, :system_time, :monotonic_time, :unique_integer]
  @calls [
    {[:DateTime], :utc_now},
    {[:NaiveDateTime], :utc_now},
    {[:Date], :utc_today},
    {:crypto, :strong_rand_bytes},
    {[:Kernel], :make_ref},
    {:local, :make_ref}
  ]

  @impl Credo.Check
  def run(source_file, params) do
    if Source.build_config_file?(source_file), do: issues(source_file, params), else: []
  end

  defp issues(source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Source.reduce(source_file, [], fn node, scope, issues ->
      case Source.call(node, scope) do
        {module, name, meta, _args}
        when {module, name} in @calls or module == :rand or
               (module == [:System] and name in @system_functions) ->
          issue =
            format_issue(issue_meta,
              message:
                "Move nondeterministic values to config/runtime.exs or generate them at runtime.",
              trigger: Atom.to_string(name),
              line_no: meta[:line],
              column: meta[:column]
            )

          [issue | issues]

        _ ->
          issues
      end
    end)
  end
end
