defmodule TestCritic.Credo.Check.UnverifiedMoxExpect do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [verifying_case_templates: []],
    explanations: [
      check: """
      ETC-MOCK-004: Register Mox verification in setup for each test that
      calls Mox.expect/3 or Mox.expect/4. Without verification, unmet
      expectations can pass silently.
      """,
      params: [
        verifying_case_templates:
          "Modules that register Mox verification for every test using them."
      ]
    ]

  @impl Credo.Check
  def run(source_file, params) do
    templates =
      params
      |> Params.get(:verifying_case_templates, __MODULE__)
      |> Enum.map(&Module.split/1)

    issue_meta = IssueMeta.for(source_file, params)

    Source.reduce(source_file, [], fn
      {:defmodule, _, [_, [do: body]]}, scope, issues ->
        case first_unverified_expect(body, scope, templates) do
          nil ->
            issues

          meta ->
            issue =
              format_issue(issue_meta,
                message:
                  "Register Mox.verify_on_exit! in setup so ExUnit checks every expectation.",
                trigger: "expect",
                line_no: meta[:line],
                column: meta[:column]
              )

            [issue | issues]
        end

      _node, _scope, issues ->
        issues
    end)
  end

  defp first_unverified_expect(body, scope, templates) do
    if Enum.any?(Source.expressions(body), &test_declaration?/1) do
      body
      |> unverified_expects(scope, templates)
      |> Enum.min_by(&{&1[:line], &1[:column]}, fn -> nil end)
    end
  end

  defp test_declaration?({name, _, _}) when name in [:test, :describe, :use], do: true
  defp test_declaration?(_node), do: false

  defp unverified_expects(body, scope, templates) do
    {verified?, expects} =
      Source.reduce(body, scope, {false, []}, fn
        {:defmodule, _, _}, _scope, facts ->
          {:skip, facts}

        {:describe, _, [_, [do: block]]}, scope, {verified?, expects} ->
          {:skip, {verified?, unverified_expects(block, scope, templates) ++ expects}}

        {:use, _, [module | _]}, scope, {verified?, expects} ->
          used_module = Source.module_name(module, scope)

          verifies? =
            is_list(used_module) and Enum.map(used_module, &Atom.to_string/1) in templates

          {verified? or verifies?, expects}

        {:setup, _, arguments}, scope, {verified?, expects} when is_list(arguments) ->
          {verified? or verifying_setup?(arguments, scope), expects}

        node, scope, {verified?, expects} ->
          {verified?, collect_expect(node, scope, expects)}
      end)

    if verified?, do: [], else: expects
  end

  defp collect_expect(node, scope, expects) do
    with {module, :expect, meta, args} when length(args) in [3, 4] <- Source.call(node, scope),
         true <- mox_call?(module, :expect, args, scope) do
      [meta | expects]
    else
      _ -> expects
    end
  end

  defp verifying_setup?(arguments, scope) do
    case List.last(arguments) do
      :verify_on_exit! -> true
      [do: block] -> verifying_block?(block, scope)
      callbacks -> Enum.any?(List.wrap(callbacks), &verification_callback?(&1, scope))
    end
  end

  defp verification_callback?(:verify_on_exit!, _scope), do: true

  defp verification_callback?({module, :verify_on_exit!}, scope),
    do: Source.module_name(module, scope) == [:Mox]

  defp verification_callback?(_callback, _scope), do: false

  defp verifying_block?(block, scope) do
    Source.reduce(block, scope, false, fn
      {kind, _, _}, _scope, verified? when kind in [:fn, :def, :defp, :defmodule] ->
        {:skip, verified?}

      node, scope, verified? ->
        case Source.call(node, scope) do
          {module, :verify_on_exit!, _, args} when length(args) in [0, 1] ->
            verified? or mox_call?(module, :verify_on_exit!, args, scope)

          _ ->
            verified?
        end
    end)
  end

  defp mox_call?([:Mox], _name, _args, _scope), do: true

  defp mox_call?(:local, name, args, scope),
    do: Source.imported?(scope, [:Mox], name, length(args))

  defp mox_call?(_module, _name, _args, _scope), do: false
end
