---
id: ETC-CORE-007
title: "Name tests with precondition and outcome"
category: core
severity: style
summary: >
  Write test names that describe both the precondition (given) and the expected
  outcome (then), so a failing test name alone tells you what broke and why.
  Avoid vague names like "works" or "test 1".
principles:
  - public-interface
applies_when:
  - "All ExUnit test names"
  - "Any test where the name does not already contain the scenario and expected result"
---

# Name tests with precondition and outcome

A good test name answers two questions: "under what condition?" and "what should happen?"
When a test fails in CI, you read the test name before the stack trace. A name like
`"returns {:error, :not_found} when the user does not exist"` immediately tells you
the function, the scenario, and the expectation. A name like `"test 3"` tells you nothing.

## Problem

Vague test names produce opaque failure output. When `"test 3"` or `"handles user"` fails,
you must open the file and read the test body to understand what broke. In a suite with
hundreds of tests, vague names make failures hard to triage without a local checkout.

The naming pattern `"[outcome] when [precondition]"` or `"[precondition] [outcome]"` is
idiomatic Elixir and aligns with how ExUnit formats test names in its output
(e.g., `test "returns nil when user not found"`).

## Detection

- Test names shorter than 5 words that don't include a function name, return value, or condition
- Names like `"test N"`, `"works"`, `"handles X"`, `"it does Y"`
- Names that describe the implementation step rather than the observable outcome

## Bad

```elixir
describe "find_user/1" do
  test "found" do ...end
  test "not found" do ... end
  test "invalid input" do ... end
end
```

## Good

```elixir
describe "find_user/1" do
  test "returns the user struct when found by id" do ... end
  test "returns nil when no user exists with that id" do ... end
  test "returns {:error, :invalid_id} when id is not a positive integer" do ... end
end
```

## When This Applies

- Every test in a codebase, but especially tests in `describe` blocks where context
  already establishes the function name
- Tests that will appear in CI output, dashboards, or test reports read by other developers

## When This Does Not Apply

- Doctests: the test name is derived from the docstring example; naming is not under
  the developer's direct control
- Property-based tests: the framework generates names from the property definition

## Further Reading

- [ExUnit.Case — test/3](https://hexdocs.pm/ex_unit/ExUnit.Case.html#test/3)
- [Chris McCord — "Naming tests"](https://phoenixframework.org/blog/testing-channels)
