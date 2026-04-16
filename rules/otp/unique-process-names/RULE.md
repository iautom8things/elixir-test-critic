---
id: ETC-OTP-004
title: "Use unique names for per-test processes"
category: otp
severity: warning
summary: >
  When registering a GenServer under a name in tests, use a unique name per
  test (e.g., derived from the test's pid or a unique ref) to avoid conflicts
  between concurrently running tests.
principles:
  - async-default
applies_when:
  - "Tests start a named GenServer (via name: :my_server or via: {:local, name})"
  - "The test file uses async: true"
  - "Multiple tests in the same file or suite start processes with the same name"
---

# Use unique names for per-test processes

When tests register processes under a global name, concurrently running tests
compete for the same name. The second test to register the name gets an
`{:error, {:already_started, pid}}` error, causing intermittent failures that
are difficult to reproduce locally.

## Problem

Elixir's process registry (and `Registry`) uses names as unique keys. If two
concurrent tests both call `GenServer.start_link(__MODULE__, [], name: :my_cache)`,
the second one fails because `:my_cache` is already registered. Since async tests
run in parallel, this creates a flaky-test time bomb: tests pass in isolation but
fail under `mix test` when many tests run at once.

The solution is to derive a unique name per test, either by using a ref, the test
process's pid, or via `ExUnit`'s test context. Alternatively, start the process
without a name and pass the pid explicitly — named processes are rarely needed in
tests.

## Detection

- `GenServer.start_link` with a hardcoded atom `name:` option in a test file
  using `async: true`
- `start_supervised({MyServer, name: :fixed_name})` in an async test
- A `setup` block that registers a process under a constant atom name

## Bad

```elixir
defmodule MyApp.CacheTest do
  use ExUnit.Case, async: true

  setup do
    # Two concurrent tests will both try to register :my_cache — one will fail
    {:ok, _pid} = start_supervised({MyApp.Cache, name: :my_cache})
    :ok
  end

  test "stores a value" do
    MyApp.Cache.put(:my_cache, :key, "value")
    assert MyApp.Cache.get(:my_cache, :key) == "value"
  end
end
```

## Good

```elixir
defmodule MyApp.CacheTest do
  use ExUnit.Case, async: true

  setup do
    # Unique name per test: no collision between concurrent runs
    name = :"cache_#{System.unique_integer([:positive])}"
    {:ok, _pid} = start_supervised({MyApp.Cache, name: name})
    %{cache: name}
  end

  test "stores a value", %{cache: cache} do
    MyApp.Cache.put(cache, :key, "value")
    assert MyApp.Cache.get(cache, :key) == "value"
  end
end
```

## When This Applies

- Any async test that starts a named process
- Shared setup blocks (in `setup` or `setup_all`) that register processes by name
- Tests that use `Registry` with a fixed key

## When This Does Not Apply

- Sequential tests (`async: false`) where there is no concurrency
- Tests that use `start_supervised` without a name (the pid is used directly)
- Integration tests that spin up a full application under supervision
  (the supervisor handles naming internally)

## Further Reading

- [ExUnit.Case — start_supervised/2](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#start_supervised/2)
- [System.unique_integer/1](https://hexdocs.pm/elixir/System.html#unique_integer/1)
- [Elixir — Process registration](https://hexdocs.pm/elixir/Process.html#register/2)
