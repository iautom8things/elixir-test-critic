---
id: ETC-OTP-001
title: "Test the pure module, not the GenServer wrapper"
category: otp
severity: recommendation
summary: >
  GenServers should be thin wrappers around pure logic modules. Test the logic
  module directly with unit tests instead of routing every assertion through
  the GenServer process.
principles:
  - purity-separation
  - thin-processes
applies_when:
  - "A GenServer delegates to a separate pure module for business logic"
  - "The logic can be tested without a running process"
  - "You want fast, deterministic unit tests for core logic"
related_rules:
  - ETC-OTP-002
  - ETC-ABS-001
  - ETC-BWAY-004
---

# Test the pure module, not the GenServer wrapper

GenServers should be thin wrappers around pure logic modules. When your GenServer
delegates to a pure module for its actual work, test that module directly — not
through the GenServer process.

## Problem

When developers write all their tests against a GenServer rather than the
underlying logic module, several problems emerge. Tests become slower because
every assertion requires spawning and messaging a process. Tests become harder
to isolate because process state can bleed between assertions. Error messages
become cryptic because failures surface as `{:error, ...}` returns from
`GenServer.call` rather than clean assertion failures. Most importantly, it
encourages coupling business logic to process infrastructure — a design smell
that compounds over time.

The right structure: a pure module holds all the logic, and the GenServer is
a thin shell that holds state and delegates to the pure module. Test the pure
module with fast unit tests; test the GenServer only for process-level concerns
(state lifecycle, concurrency, crash recovery).

## Detection

- A GenServer with `handle_call` or `handle_cast` callbacks containing more than
  a few lines of actual computation (not just delegation)
- Test files that only `start_supervised` a GenServer and never call the pure module
- Logic tests that use `GenServer.call/2` to verify transformation results
- No separate module (e.g., `MyApp.Counter.State`) alongside `MyApp.Counter`

## Bad

```elixir
# All tests go through the GenServer process even for pure logic
defmodule MyApp.CounterTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = start_supervised(MyApp.Counter)
    %{pid: pid}
  end

  test "increment adds 1", %{pid: pid} do
    GenServer.cast(pid, :increment)
    Process.sleep(10)  # hoping the cast was processed
    assert GenServer.call(pid, :get) == 1
  end
end
```

## Good

```elixir
# Test the pure logic module directly
defmodule MyApp.CounterLogicTest do
  use ExUnit.Case, async: true

  alias MyApp.CounterLogic

  test "increment adds 1 to state" do
    assert CounterLogic.increment(0) == 1
  end

  test "increment is composable" do
    result = 0 |> CounterLogic.increment() |> CounterLogic.increment()
    assert result == 2
  end
end
```

## When This Applies

- When a GenServer has a companion pure module that holds business logic
- When testing mathematical or data-transformation logic that lives inside a GenServer
- When your GenServer callbacks do substantial computation that could be extracted

## When This Does Not Apply

- When the GenServer IS the unit being tested (e.g., testing process lifecycle,
  crash recovery, or message ordering)
- When the logic is genuinely stateful and cannot be meaningfully separated
- When testing OTP supervision trees or restart behaviour

## Further Reading

- [Saša Jurić — "Supervise Me" (ElixirConf EU 2019)](https://www.youtube.com/watch?v=fTTyQNd_loA)
- [José Valim — "Elixir in Production" talks on thin processes]
- [Elixir docs — GenServer](https://hexdocs.pm/elixir/GenServer.html)
