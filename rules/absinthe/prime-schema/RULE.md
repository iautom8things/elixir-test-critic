---
id: ETC-ABS-004
title: "Call Absinthe.Test.prime/1 in test_helper.exs"
category: absinthe
severity: warning
summary: >
  Add `Absinthe.Test.prime(MyApp.Schema)` to `test/test_helper.exs`. Absinthe
  lazily compiles schemas on first use. Without priming, the first test to
  execute a query against the schema bears the full compilation cost and can
  cause flaky timeouts, especially in concurrent test suites.
principles:
  - async-default
applies_when:
  - "Any project using Absinthe with schema tests"
  - "Concurrent (async: true) Absinthe test suites"
  - "CI environments where test timeouts are tight"
related_rules:
  - ETC-CORE-001
  - ETC-ABS-002
---

# Call Absinthe.Test.prime/1 in test_helper.exs

Absinthe compiles schema modules lazily — the first execution of a query
against a schema triggers compilation of the full type system. This
compilation:

- Takes hundreds of milliseconds for a non-trivial schema
- Is not parallelised across test processes
- Can cause the first test to hit the schema to exceed its timeout
- Can cause races when multiple async tests start simultaneously and each
  tries to trigger the compilation

`Absinthe.Test.prime/1` compiles the schema synchronously during test suite
startup, before any test begins, so all tests see a pre-compiled schema.

## Problem

Without priming, async test suites see intermittent failures like:

```
** (ExUnit.TimeoutError) test timed out after 60000ms
```

or worse, tests fail nondeterministically because the first test always bears
the compilation cost and sometimes exceeds its timeout.

## Detection

- No call to `Absinthe.Test.prime/1` in `test/test_helper.exs`
- Flaky timeouts in the first Absinthe schema test to run

## Bad

```elixir
# test/test_helper.exs — missing schema priming
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)
```

## Good

```elixir
# test/test_helper.exs — schema is compiled before tests begin
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

- Any project that tests against an Absinthe schema
- Especially important for async (`async: true`) test suites
- CI pipelines with tight test timeout budgets

## When This Does Not Apply

- Projects that do not have any direct Absinthe schema tests (only HTTP
  tests through ConnCase with no `Absinthe.run/3` calls) — the schema is
  warmed by the first HTTP request in that case, but priming is still
  recommended

## Further Reading

- [Absinthe.Test.prime/1](https://hexdocs.pm/absinthe/Absinthe.Test.html#prime/1)
- [Absinthe testing guide](https://hexdocs.pm/absinthe/testing.html)
