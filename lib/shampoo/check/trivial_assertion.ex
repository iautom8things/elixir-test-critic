defmodule Shampoo.Check.TrivialAssertion do
  alias Shampoo.Check.Source

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
  @type_guards [
    :is_atom,
    :is_binary,
    :is_bitstring,
    :is_boolean,
    :is_exception,
    :is_float,
    :is_function,
    :is_integer,
    :is_list,
    :is_map,
    :is_nil,
    :is_number,
    :is_pid,
    :is_port,
    :is_reference,
    :is_struct,
    :is_tuple
  ]
  @two_argument_guards [:is_exception, :is_function, :is_map_key, :is_struct]

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
         true <- trivial?(name, expression, scope) do
      issue =
        format_issue(issue_meta,
          message: message(name, expression),
          trigger: Atom.to_string(name),
          line_no: meta[:line],
          column: meta[:column]
        )

      [issue | issues]
    else
      _ -> issues
    end
  end

  defp message(:assert, true) do
    "Assert the real condition, tag the test to skip when a prerequisite is missing, or delete the branch."
  end

  defp message(_name, _expression), do: "Assert an observable result from the code under test."

  defp trivial?(:refute, expression, _scope) when expression in [false, nil], do: true

  defp trivial?(:assert, {operator, _, [expression]}, _scope)
       when operator in [:!, :not] and expression in [false, nil],
       do: true

  defp trivial?(name, {operator, _, [left, right]}, _scope) when operator in @comparisons do
    (literal?(left) and literal?(right)) or
      (name == :assert and operator in [:==, :===] and
         reference?(left) and reference?(right) and without_meta(left) === without_meta(right))
  end

  defp trivial?(name, expression, scope) do
    literal_guard?(Source.call(expression, scope)) or
      (name == :assert and expression not in [false, nil] and literal?(expression))
  end

  defp literal_guard?({module, name, _, [value]})
       when module in [:local, [:Kernel], :erlang] and name in @type_guards,
       do: literal?(value)

  defp literal_guard?({module, name, _, [left, right]})
       when module in [:local, [:Kernel], :erlang] and name in @two_argument_guards,
       do: literal?(left) and literal?(right)

  defp literal_guard?(_call), do: false

  defp literal?({sign, _, [number]}) when sign in [:+, :-] and is_number(number), do: true
  defp literal?(expression), do: Macro.quoted_literal?(expression)

  defp reference?({:@, _, [{name, _, context}]}) when is_atom(name) and is_atom(context), do: true
  defp reference?({name, _, context}) when is_atom(name) and is_atom(context), do: true

  defp reference?({{:., _, [receiver, field]}, meta, []}) when is_atom(field),
    do: meta[:no_parens] == true and reference?(receiver)

  defp reference?(_expression), do: false

  defp without_meta(ast), do: Macro.prewalk(ast, &Macro.update_meta(&1, fn _ -> [] end))
end
