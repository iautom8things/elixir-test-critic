---
id: ETC-OTP-002
title: "Prefer testing GenServers through their public API"
category: otp
severity: warning
summary: >
  Test GenServer behaviour through its public API functions rather than
  inspecting internal state with :sys.get_state/1. Internal state is an
  implementation detail; the public API is the contract.
principles:
  - public-interface
applies_when:
  - "Testing a GenServer that has public API functions surfacing relevant state"
  - "Verifying that a GenServer responds correctly to messages or calls"
  - "Writing tests that should survive internal refactoring"
does_not_apply_when:
  - "The GenServer has no public API that surfaces the state being tested"
  - "Debugging during development — :sys.get_state/1 is a legitimate debugging tool"
related_rules:
  - ETC-OTP-001
---

# Prefer testing GenServers through their public API

A GenServer's internal state is an implementation detail. Tests that peek at
it via `:sys.get_state/1` couple themselves to the current representation and
break on refactoring even when behaviour is unchanged.

## Problem

`:sys.get_state/1` gives you raw access to a GenServer's state term. This is
invaluable for debugging, but it's a trap in tests. When you assert on raw
state, your tests know too much: the exact shape of the map, the names of
internal fields, the ordering of a list. Any refactoring that preserves
observable behaviour but changes internal representation will break these tests.

Worse, tests using `:sys.get_state/1` signal that the GenServer lacks a
sufficient public API. Instead of adding `:sys.get_state/1` calls, add the
missing public function.

## Detection

- Any call to `:sys.get_state/1` or `:sys.replace_state/2` in test files
- Assertions on raw map fields that match internal GenServer state shape
- Test setup that uses `:sys.replace_state/2` to pre-configure process state

## Bad

```elixir
defmodule MyApp.CacheTest do
  use ExUnit.Case, async: true

  test "put stores the value internally" do
    {:ok, pid} = start_supervised(MyApp.Cache)
    MyApp.Cache.put(pid, :key, "value")
    # Inspects internal state — breaks if the map structure changes
    state = :sys.get_state(pid)
    assert state.entries[:key] == "value"
  end
end
```

## Good

```elixir
defmodule MyApp.CacheTest do
  use ExUnit.Case, async: true

  test "put stores a value retrievable via get" do
    {:ok, pid} = start_supervised(MyApp.Cache)
    MyApp.Cache.put(pid, :key, "value")
    # Tests the public contract, not internal representation
    assert MyApp.Cache.get(pid, :key) == "value"
  end
end
```

## When This Applies

- Any GenServer that has public API functions surfacing the state being tested
- Tests that are meant to survive internal refactoring
- CI test suites where test brittleness is a concern

## When This Does Not Apply

- The GenServer genuinely has no public API that exposes the state you need to verify.
  In this case, first consider adding the missing API function. If that's not possible
  or desirable (e.g., a third-party GenServer you don't control), `:sys.get_state/1`
  is acceptable.
- Interactive debugging sessions (`iex -S mix`), where `:sys.get_state/1` is exactly
  the right tool.
- One-off introspection tests that explicitly document they are implementation-detail
  tests, not contract tests.

## Further Reading

- [Erlang :sys module](https://www.erlang.org/doc/man/sys.html)
- [Elixir docs — GenServer](https://hexdocs.pm/elixir/GenServer.html)
- [Growing Object-Oriented Software, Guided by Tests — "Don't Mock What You Don't Own"](http://www.growing-object-oriented-software.com/)
