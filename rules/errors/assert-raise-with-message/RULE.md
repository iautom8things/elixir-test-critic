---
id: ETC-ERR-001
title: "Use 3-arity assert_raise with message matching"
category: errors
severity: warning
summary: >
  Use `assert_raise/3` (exception module + message pattern) instead of `assert_raise/2`
  (exception module only) to verify both that the right exception type was raised and
  that it was raised for the right reason.
principles:
  - public-interface
applies_when:
  - "Any test asserting that a function raises an exception"
  - "When the exception message carries meaningful information about the failure reason"
---

# Use 3-arity assert_raise with message matching

`assert_raise/2` verifies that the expected exception *type* was raised, but it
accepts any message. `assert_raise/3` adds a message check — either an exact string
or a regex — so the test also verifies the *reason* for the exception.

## Problem

`assert_raise(ArgumentError, fn -> ...)` passes whenever *any* `ArgumentError` is
raised — even if it comes from a completely different code path with a different
message. This creates a category of false positives:

- Code path A raises `ArgumentError, "expected a positive integer"`
- Code path B raises `ArgumentError, "expected a string"`
- A refactoring moves the logic so code path A no longer runs, but code path B
  still raises `ArgumentError` for a different input
- The 2-arity test still passes, hiding the regression

By matching on the message, the test documents the specific failure contract and
catches the case where the exception type is right but the source is wrong.

## Detection

- `assert_raise SomeError, fn -> ...` without a message argument
- 2-arity `assert_raise` for exceptions that carry meaningful error messages
- Exception types that are broad (`ArgumentError`, `RuntimeError`) — these especially
  benefit from message matching since many code paths can raise them

## Bad

```elixir
test "raises when given a negative integer" do
  # Passes for ANY ArgumentError — including ones from the wrong code path
  assert_raise ArgumentError, fn ->
    MyModule.process(-1)
  end
end
```

## Good

```elixir
test "raises when given a negative integer" do
  # Passes only when ArgumentError is raised WITH this specific message
  assert_raise ArgumentError, ~r/expected a positive integer/, fn ->
    MyModule.process(-1)
  end
end
```

Or with an exact string:

```elixir
test "raises when given a negative integer" do
  assert_raise ArgumentError, "expected a positive integer, got: -1", fn ->
    MyModule.process(-1)
  end
end
```

## When This Applies

- Any `assert_raise` for exceptions with meaningful error messages
- Especially important for broad exception types (`ArgumentError`, `RuntimeError`, `ErlangError`)
  that many different code paths can raise

## When This Does Not Apply

- Exceptions whose message is deliberately unstable or implementation-defined
  (e.g., exceptions raised inside a library you don't control)
- When the test is specifically asserting "this raises *something*" as a contract,
  and the specific message is not part of the public contract
- Very specific exception structs with no human-readable message field

## Further Reading

- [ExUnit.Assertions — assert_raise/3](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_raise/3)
