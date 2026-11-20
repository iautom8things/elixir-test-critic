---
id: ETC-CORE-013
title: "Assert observable results"
category: core
severity: warning
summary: >
  Assert a result produced by the code under test so a change in behavior can make the test fail.
principles:
  - public-interface
applies_when:
  - "The assertion is intended to verify the behavior of a function or process."
does_not_apply_when:
  - "A value from the code under test is compared with an independently chosen expectation."
enforced_by: credo:Shampoo.Check.TrivialAssertion
---

# Assert observable results

Assert a result produced by the code under test so a change in behavior can make the test fail.

## Problem

An assertion about a constant or a value compared with itself can pass even when the implementation returns the wrong result.

## Detection

Look for `assert true`, a variable or field compared with itself, `assert is_atom(SomeModule)`, and comparisons between two literals. Two calls can produce different results even when they take the same arguments.

## Bad

```elixir
total = Enum.sum([19, 23])
assert total == total
```

## Good

```elixir
total = Enum.sum([19, 23])
assert total == 42
```

## When This Applies

- The assertion is intended to verify the behavior of a function or process.

## When This Does Not Apply

- A value from the code under test is compared with an independently chosen expectation.

## Further Reading

- [ExUnit.Assertions.assert/1](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert/1)
