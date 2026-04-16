---
id: ETC-ISO-003
title: "Do not share ETS/persistent_term in async tests"
category: isolation
severity: critical
summary: >
  Do not write to named ETS tables or `persistent_term` values in async tests.
  Both are global, VM-wide mutable stores. Writes in one async test corrupt the
  state seen by all concurrent tests.
principles:
  - async-default
applies_when:
  - "Any async test that writes to a named ETS table"
  - "Any async test that calls persistent_term.put/2"
  - "Tests that rely on ETS state being a specific value at assertion time"
does_not_apply_when:
  - "Read-only ETS tables populated once in test_helper.exs before any tests run"
related_rules:
  - ETC-TELE-003
---

# Do not share ETS/persistent_term in async tests

ETS tables created with a name (`:named_table`) and `persistent_term` are accessible
from any process in the VM by their name. They are the Elixir equivalent of global
mutable variables. Writing to them in async tests causes the same class of races as
`Application.put_env` — tests interfere with each other in timing-dependent ways.

## Problem

`persistent_term` is even more dangerous than ETS in tests because it is optimised
for reads — every write triggers a full GC across all processes in the VM. Using
`persistent_term.put/2` in tests causes:

1. **State pollution**: a value written by test A is visible to test B
2. **Performance degradation**: each `persistent_term.put` during testing may trigger
   a global GC pause

Named ETS tables are slightly less destructive but have the same isolation problem.
Two async tests both performing `:ets.insert(:my_cache, {key, value})` see each
other's writes.

## Detection

- `:ets.insert/2` or `:ets.delete/2` on a named table in an async test
- `persistent_term.put/2` anywhere in test code
- `:ets.new/2` with `:named_table` in a `setup` or test body (without per-test unique name)
- Tests that read from ETS and assert specific values may be reading state written by
  a concurrent test

## Bad

```elixir
defmodule MyApp.CacheTest do
  use ExUnit.Case, async: true

  test "stores a value in the shared cache" do
    :ets.insert(:my_shared_cache, {:key, "value"})
    assert [{:key, "value"}] == :ets.lookup(:my_shared_cache, :key)
  end
end
```

## Good

```elixir
defmodule MyApp.CacheTest do
  use ExUnit.Case, async: true

  setup do
    # Per-test ETS table with a unique name — not shared across tests
    table = :ets.new(:"cache_#{System.unique_integer([:positive])}", [:set, :public])
    on_exit(fn -> :ets.delete(table) end)
    %{table: table}
  end

  test "stores a value in an isolated cache", %{table: table} do
    :ets.insert(table, {:key, "value"})
    assert [{:key, "value"}] == :ets.lookup(table, :key)
  end
end
```

## When This Applies

- All async tests that write to ETS or `persistent_term`
- Tests for modules that use ETS as their internal storage mechanism

## When This Does Not Apply

- **Read-only tables in `test_helper.exs`**: if `test_helper.exs` populates an ETS table
  once (e.g., with reference data) before tests start, all tests can safely read from it
  because no test writes to it
- **Sequential tests with cleanup**: `async: false` tests that write to named ETS and
  clean up in `on_exit` are safe (though still a code smell if avoidable)

## Further Reading

- [Erlang :ets module docs](https://www.erlang.org/doc/man/ets.html)
- [:persistent_term module docs](https://www.erlang.org/doc/man/persistent_term.html)
- [Elixir forum — ETS in tests](https://elixirforum.com/t/ets-tables-in-tests/12345)
