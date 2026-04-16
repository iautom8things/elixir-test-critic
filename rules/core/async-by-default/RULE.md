---
id: ETC-CORE-001
title: "Use async: true by default"
category: core
severity: warning
summary: >
  Every ExUnit test case should use `async: true` unless it genuinely requires
  exclusive access to shared global state. Sequential tests are a code smell
  indicating leaked mutable state.
principles:
  - async-default
applies_when:
  - "Any ExUnit test module that does not require global shared state"
  - "Tests that use Ecto with SQL Sandbox (async is supported)"
  - "Tests that use Mox (allowances enable async)"
  - "Tests for pure functions, data transformations, or any stateless logic"
related_rules:
  - ETC-ABS-004
  - ETC-BWAY-004
---

# Use async: true by default

Every ExUnit test case should declare `async: true` unless the test genuinely requires
exclusive access to global mutable state. Omitting `async: true` forces the test suite
to run sequentially and masks isolation problems that will bite you later.

## Problem

When developers omit `use ExUnit.Case, async: true`, tests run in the default sequential
mode. Sequential mode hides isolation failures — two tests can share state and pass
individually while breaking when their order changes. It also makes the suite slower
for no benefit. The longer a codebase runs sequentially, the harder it becomes to
parallelise later because hidden coupling accumulates.

## Detection

- Any `use ExUnit.Case` without `, async: true`
- Modules that use `use ExUnit.Case` and only test pure functions or stateless logic
- Test modules that have no `Application.put_env`, no global ETS writes, no shared named processes

## Bad

```elixir
defmodule MyApp.MathTest do
  use ExUnit.Case   # missing async: true — runs sequentially with no reason

  test "adds two numbers" do
    assert MyApp.Math.add(1, 2) == 3
  end
end
```

## Good

```elixir
defmodule MyApp.MathTest do
  use ExUnit.Case, async: true

  test "adds two numbers" do
    assert MyApp.Math.add(1, 2) == 3
  end
end
```

## When This Applies

- All test modules that do not mutate global application environment
- Tests using Ecto SQL Sandbox (the sandbox itself is designed for async use)
- Tests using Mox (use `Mox.set_mox_from_context/1` in setup for async safety)
- Tests using `start_supervised` — the supervisor is per-test and safe for async

## When This Does Not Apply

- Tests that call `Application.put_env/3` or `Application.delete_env/2` at the test level
- Tests that write to named ETS tables shared across processes
- Tests that depend on a singleton named process with no isolation mechanism
- Tests that set global Logger configuration

## Further Reading

- [ExUnit.Case docs — async option](https://hexdocs.pm/ex_unit/ExUnit.Case.html)
- [José Valim — "Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
- [Saša Jurić — "Testing Elixir" (ElixirConf)](https://www.youtube.com/watch?v=LjTpNVqPL-Y)
