---
id: ETC-PHX-003
title: "ConnCase tests are async-safe by default"
category: phoenix
severity: recommendation
summary: >
  Phoenix ConnCase with Ecto's SQL sandbox supports `async: true` out of the box.
  Mark all ConnCase test modules as async unless you have a documented reason not
  to — omitting it halves parallelism for no benefit.
principles:
  - async-default
applies_when:
  - "Any Phoenix ConnCase test module"
  - "Any test using Ecto.Adapters.SQL.Sandbox for database isolation"
  - "API endpoint tests, HTML controller tests, plug pipeline tests"
---

# ConnCase tests are async-safe by default

Phoenix's `ConnCase` template uses Ecto's SQL sandbox, which supports concurrent
tests through a per-test transaction strategy. Every test gets its own database
transaction that is rolled back after the test completes — no cross-test data
leakage, full concurrency.

Developers sometimes omit `async: true` thinking Phoenix or database access
requires sequential execution. It does not. The absence of `async: true` in a
ConnCase module is almost always an oversight.

## Problem

Sequential ConnCase test suites are common in projects that followed old tutorials
or cargo-culted from pre-sandbox codebases. The result is a test suite that runs
four to ten times slower than it needs to, with no correctness benefit. The
sequential constraint also masks isolation failures — tests that share state via
leaky globals will pass sequentially but fail in parallel, so the bug is never
surfaced.

## Detection

- `use MyAppWeb.ConnCase` without `, async: true`
- `use MyAppWeb.ConnCase, async: false` (explicit false, likely unnecessary)

## Bad

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase   # no async: true — sequential for no reason

  test "lists users", %{conn: conn} do
    conn = get(conn, ~p"/users")
    assert html_response(conn, 200) =~ "Users"
  end
end
```

## Good

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase, async: true

  test "lists users", %{conn: conn} do
    conn = get(conn, ~p"/users")
    assert html_response(conn, 200) =~ "Users"
  end
end
```

## When This Applies

- All ConnCase test modules that do not mutate global application state
- All ConnCase tests that use the SQL sandbox (the default Phoenix setup)

## When This Does Not Apply

- Tests that call `Application.put_env/3` globally (use `put_env_in_test/3` pattern instead)
- Tests that depend on singleton named processes not isolated per-test
- Tests that use external services that require exclusive access
- Tests explicitly testing concurrent request behaviour where ordering matters

## Further Reading

- [Ecto SQL Sandbox docs](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [Phoenix testing guide — ConnCase](https://hexdocs.pm/phoenix/testing_controllers.html)
- [ExUnit async option](https://hexdocs.pm/ex_unit/ExUnit.Case.html)
