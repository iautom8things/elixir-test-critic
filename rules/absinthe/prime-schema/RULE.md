---
id: ETC-ABS-004
title: "Call Absinthe.Test.prime/1 in test_helper.exs"
category: absinthe
severity: recommendation
summary: >
  Add `Absinthe.Test.prime(MyApp.Schema)` to `test/test_helper.exs`. In the test
  environment Mix loads code lazily, so the first GraphQL query in the suite also
  loads Absinthe's modules. That takes several milliseconds and can push a
  message-passing test past a tight timeout.
principles:
  - async-default
applies_when:
  - "A project has Absinthe tests that wait for messages with short timeouts: subscriptions, PubSub, assert_receive"
related_rules:
  - ETC-CORE-001
  - ETC-ABS-002
---

# Call Absinthe.Test.prime/1 in test_helper.exs

In the test environment Mix loads modules the first time they are used.
Absinthe is a large code base, so the first GraphQL query in a test run also
loads most of Absinthe. Absinthe's documentation puts the cost at several
milliseconds.

`Absinthe.Test.prime/1` runs the introspection query against the schema during
suite startup. That loads the code before any test begins. It does not compile
the schema: Absinthe schemas are compiled with the rest of the application.

## Problem

The cost is small and lands on whichever test runs a query first. It matters
only for a test that expects a message within a short window, such as an
`assert_receive` with the default 100 ms timeout on a subscription push. On a
loaded CI machine the code loading can use up enough of that window to fail the
test, and the failure moves to a different test each time the order changes.

## Detection

- `:absinthe` is a dependency, tests use `assert_receive` on GraphQL results or
  subscription pushes, and `test/test_helper.exs` has no `Absinthe.Test.prime/1`
- An intermittent timeout in whichever Absinthe test happens to run first

## Bad

```elixir
# test/test_helper.exs — missing schema priming
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)
```

## Good

```elixir
# test/test_helper.exs: Absinthe's code is loaded before tests begin
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)
Absinthe.Test.prime(MyApp.Schema)
```

If your application has multiple schemas, prime each one:

```elixir
Absinthe.Test.prime(MyApp.Schema)
Absinthe.Test.prime(MyApp.AdminSchema)
```

## When This Applies

- Projects with Absinthe tests that assert on messages inside short timeouts

## When This Does Not Apply

- Suites with no timing-sensitive Absinthe tests. Priming is harmless there and
  buys nothing measurable.

## Further Reading

- [Absinthe.Test.prime/1](https://hexdocs.pm/absinthe/Absinthe.Test.html#prime/1)
- [Absinthe testing guide](https://hexdocs.pm/absinthe/testing.html)
