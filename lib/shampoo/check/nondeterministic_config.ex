defmodule Shampoo.Check.NondeterministicConfig do
  alias Shampoo.Check.Source

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
    {[:Ecto, :UUID], :generate},
    {:crypto, :strong_rand_bytes},
    {:erlang, :unique_integer},
    {:erlang, :make_ref},
    {:os, :system_time},
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
      case nondeterministic_call(Source.call(node, scope), scope) do
        {name, meta} ->
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

  defp nondeterministic_call({module, name, meta, _args}, _scope)
       when {module, name} in @calls or module == :rand or
              (module == [:System] and name in @system_functions),
       do: {name, meta}

  defp nondeterministic_call({:local, name, meta, args}, scope) when name in @system_functions do
    if length(args) in [0, 1] and Source.imported?(scope, [:System], name, length(args)),
      do: {name, meta}
  end

  defp nondeterministic_call(_call, _scope), do: nil
end
