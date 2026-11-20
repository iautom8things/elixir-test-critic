defmodule TestCritic.Credo.Check.UnverifiedMoxExpect do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [verifying_case_templates: []],
    explanations: [
      check: """
      ETC-MOCK-004: Register Mox verification in setup or in each test that
      calls Mox.expect/3 or Mox.expect/4. Without verification, unmet
      expectations can pass silently.
      """,
      params: [
        verifying_case_templates:
          "Modules that register Mox verification for every test using them."
      ]
    ]

  use TestCritic.Credo.Options, verifying_case_templates: {:list, :module}

  defp analyze(source_file, params, options) do
    if Source.test_file?(source_file) and not Source.test_support_file?(source_file) do
      issues(source_file, params, Enum.map(options.verifying_case_templates, &Module.split/1))
    else
      []
    end
  end

  defp issues(source_file, params, templates) do
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
                  "Register Mox.verify_on_exit! in setup or in the test. " <>
                    "List case templates that already verify under verifying_case_templates.",
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
      {pending, helpers} = scope_facts(body, scope, templates)

      pending
      |> reachable_expects(helpers, MapSet.new(), [])
      |> Enum.min_by(&{&1[:line], &1[:column]}, fn -> nil end)
    end
  end

  defp test_declaration?({name, _, _}) when name in [:test, :describe, :use], do: true
  defp test_declaration?(_node), do: false

  defp scope_facts(body, scope, templates) do
    {verified?, pending, helpers} =
      Source.reduce(body, scope, {false, [], %{}}, fn
        {:defmodule, _, _}, _scope, facts ->
          {:skip, facts}

        {:describe, _, [_, [do: block]]}, scope, {verified?, pending, helpers} ->
          {child_pending, child_helpers} = scope_facts(block, scope, templates)
          helpers = Map.merge(helpers, child_helpers, fn _, left, right -> left ++ right end)
          {:skip, {verified?, child_pending ++ pending, helpers}}

        {:test, _, arguments}, scope, facts when is_list(arguments) ->
          if directly_verifies?(List.last(arguments), scope), do: {:skip, facts}, else: facts

        {:defp, _, [head, [do: block]]}, scope, {verified?, pending, helpers} ->
          {:skip, {verified?, pending, collect_helper(head, block, scope, helpers)}}

        {:defp, _, [head]}, scope, {verified?, pending, helpers} ->
          {:skip, {verified?, pending, collect_helper(head, nil, scope, helpers)}}

        {:use, _, [module | _]}, scope, {verified?, pending, helpers} ->
          used_module = Source.module_name(module, scope)

          verifies? =
            is_list(used_module) and Enum.map(used_module, &Atom.to_string/1) in templates

          {verified? or verifies?, pending, helpers}

        {kind, _, arguments}, scope, {verified?, pending, helpers}
        when kind in [:setup, :setup_all] and is_list(arguments) ->
          callbacks = List.last(arguments)
          verified? = verified? or (kind == :setup and verifying_setup?(callbacks, scope))
          {verified?, setup_refs(callbacks) ++ pending, helpers}

        node, scope, {verified?, pending, helpers} ->
          {verified?, collect_ref(node, scope, pending), helpers}
      end)

    {if(verified?, do: [], else: pending), helpers}
  end

  defp collect_helper({:when, _, [head | _guards]}, body, scope, helpers),
    do: collect_helper(head, body, scope, helpers)

  defp collect_helper({name, _, args}, body, scope, helpers)
       when is_atom(name) and (is_list(args) or is_nil(args)) do
    args = args || []
    max_arity = length(args)
    default_count = Enum.count(args, &match?({:\\, _, _}, &1))
    refs = Source.reduce(body, scope, [], &collect_ref/3)

    Enum.reduce((max_arity - default_count)..max_arity, helpers, fn arity, acc ->
      arity_refs = if arity == max_arity, do: refs, else: [{:helper, {name, max_arity}}]
      Map.update(acc, {name, arity}, arity_refs, &(arity_refs ++ &1))
    end)
  end

  defp collect_helper(_head, _body, _scope, helpers), do: helpers

  defp directly_verifies?([do: body], scope) do
    Source.reduce_statements(body, scope, false, fn node, scope, verified? ->
      verified? or verifies?(node, scope, [:verify!, :verify_on_exit!])
    end)
  end

  defp directly_verifies?(_block, _scope), do: false

  defp collect_ref({:&, _, [{:/, _, [{name, _, context}, arity]}]}, _scope, refs)
       when is_atom(name) and is_atom(context),
       do: [{:helper, {name, arity}} | refs]

  defp collect_ref(node, scope, refs) do
    case Source.call(node, scope) do
      {module, :expect, meta, args} when length(args) in [3, 4] ->
        if mox_call?(module, :expect, args, scope),
          do: [{:expect, meta} | refs],
          else: helper_ref(module, :expect, args, refs)

      {module, name, _, args} ->
        helper_ref(module, name, args, refs)

      _ ->
        refs
    end
  end

  defp helper_ref(:local, name, args, refs), do: [{:helper, {name, length(args)}} | refs]
  defp helper_ref(_module, _name, _args, refs), do: refs

  defp setup_refs(callbacks) do
    for name <- List.wrap(callbacks), is_atom(name), do: {:helper, {name, 1}}
  end

  defp reachable_expects([], _helpers, _visited, expects), do: expects

  defp reachable_expects([{:expect, meta} | rest], helpers, visited, expects),
    do: reachable_expects(rest, helpers, visited, [meta | expects])

  defp reachable_expects([{:helper, key} | rest], helpers, visited, expects) do
    with {:ok, refs} <- Map.fetch(helpers, key),
         false <- MapSet.member?(visited, key) do
      reachable_expects(refs ++ rest, helpers, MapSet.put(visited, key), expects)
    else
      _ -> reachable_expects(rest, helpers, visited, expects)
    end
  end

  defp verifying_setup?([do: block], scope), do: verifying_block?(block, scope)

  defp verifying_setup?(callbacks, scope),
    do: Enum.any?(List.wrap(callbacks), &verification_callback?(&1, scope))

  defp verification_callback?(:verify_on_exit!, _scope), do: true

  defp verification_callback?({module, :verify_on_exit!}, scope),
    do: Source.module_name(module, scope) == [:Mox]

  defp verification_callback?(_callback, _scope), do: false

  defp verifying_block?(block, scope) do
    Source.reduce(block, scope, false, fn
      {kind, _, _}, _scope, verified? when kind in [:fn, :def, :defp, :defmodule] ->
        {:skip, verified?}

      node, scope, verified? ->
        verified? or verifies?(node, scope, [:verify_on_exit!])
    end)
  end

  defp verifies?(node, scope, functions) do
    case Source.call(node, scope) do
      {module, name, _, args} when length(args) in [0, 1] ->
        (name in functions and mox_call?(module, name, args, scope)) or
          verifies_on_exit?(module, name, args, scope)

      {module, :on_exit, _, [_name, callback]} ->
        verifies_on_exit?(module, :on_exit, [callback], scope)

      _ ->
        false
    end
  end

  defp verifies_on_exit?(module, :on_exit, [callback], scope)
       when module in [:local, [:ExUnit, :Callbacks]],
       do: verifying_callback_term?(callback, scope)

  defp verifies_on_exit?(_module, _name, _args, _scope), do: false

  defp verifying_callback_term?({:fn, _, [{:->, _, [[], body]}]}, scope) do
    Source.reduce_statements(body, scope, false, fn node, scope, verified? ->
      verified? or verifies?(node, scope, [:verify!])
    end)
  end

  defp verifying_callback_term?({:&, _, [{:/, _, [function, 0]}]}, scope) do
    case function do
      {{:., _, [receiver, :verify!]}, _, _} ->
        Source.module_name(receiver, scope) == [:Mox]

      {:verify!, _, _} ->
        Source.imported?(scope, [:Mox], :verify!, 0)

      _ ->
        false
    end
  end

  defp verifying_callback_term?(_callback, _scope), do: false

  defp mox_call?([:Mox], _name, _args, _scope), do: true

  defp mox_call?(:local, name, args, scope),
    do: Source.imported?(scope, [:Mox], name, length(args))

  defp mox_call?(_module, _name, _args, _scope), do: false
end
