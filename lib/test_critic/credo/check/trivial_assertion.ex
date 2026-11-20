defmodule TestCritic.Credo.Check.TrivialAssertion do
  alias TestCritic.Credo.Source

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      ETC-CORE-013: Assert an observable result from the code under test.
      A comparison of constants or a value with itself can pass even when
      the behavior is broken. Separate function calls can produce different values.
      """
    ]

  @comparisons [:==, :===, :!=, :!==, :<, :<=, :>, :>=, :=~, :in]

  @impl Credo.Check
  def run(source_file, params) do
    if Source.test_file?(source_file), do: issues(source_file, params), else: []
  end

  defp issues(source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Source.reduce(source_file, [], &find_assertion(&1, &2, &3, issue_meta))
  end

  defp find_assertion(node, scope, issues, issue_meta) do
    with {module, name, meta, [expression | rest]}
         when module in [:local, [:ExUnit, :Assertions]] and name in [:assert, :refute] and
                length(rest) in 0..1 <- Source.call(node, scope),
         true <- trivial?(name, expression) do
      issue =
        format_issue(issue_meta,
          message: "Assert an observable result from the code under test.",
          trigger: Atom.to_string(name),
          line_no: meta[:line],
          column: meta[:column]
        )

      [issue | issues]
    else
      _ -> issues
    end
  end

  defp trivial?(:assert, true), do: true
  defp trivial?(:assert, {:is_atom, _, [{:__aliases__, _, _}]}), do: true

  defp trivial?(name, {operator, _, [left, right]}) when operator in @comparisons do
    (literal?(left) and literal?(right)) or
      (name == :assert and operator in [:==, :===] and
         reference?(left) and reference?(right) and without_meta(left) === without_meta(right))
  end

  defp trivial?(_name, _expression), do: false

  defp literal?({sign, _, [number]}) when sign in [:+, :-] and is_number(number), do: true
  defp literal?(expression), do: Macro.quoted_literal?(expression)

  defp reference?({:@, _, [{name, _, context}]}) when is_atom(name) and is_atom(context), do: true
  defp reference?({name, _, context}) when is_atom(name) and is_atom(context), do: true

  defp reference?({{:., _, [receiver, field]}, meta, []}) when is_atom(field),
    do: meta[:no_parens] == true and reference?(receiver)

  defp reference?(_expression), do: false

  defp without_meta(ast), do: Macro.prewalk(ast, &Macro.update_meta(&1, fn _ -> [] end))
end
