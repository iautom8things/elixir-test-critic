---
id: ETC-OTP-006
title: "Inject controllable time for periodic processes"
category: otp
severity: recommendation
summary: >
  Periodic processes that use Process.send_after or :timer.send_interval with
  real time values make tests slow and flaky. Inject the tick mechanism so tests
  can trigger ticks directly without waiting.
principles:
  - purity-separation
applies_when:
  - "A GenServer uses Process.send_after or :timer.send_interval for periodic work"
  - "Tests must wait real wall-clock time to observe periodic behaviour"
  - "The periodic interval is long enough to slow down tests meaningfully"
---

# Inject controllable time for periodic processes

Processes that use `Process.send_after` or `:timer.send_interval` with real
durations force tests to wait real time. Instead, inject the tick mechanism so
tests can send ticks directly and observe behaviour instantly.

## Problem

A GenServer with `:timer.send_interval(60_000, self(), :tick)` is untestable
at speed — tests must wait a full minute for the first tick. Developers work
around this by setting a very short interval in test config, but that's fragile
and couples the process to global configuration.

The clean solution: make the tick interval (or the tick-sender itself) an
injectable parameter. In tests, you skip the timer entirely and `send(pid, :tick)`
directly to drive the periodic logic.

## Detection

- `:timer.send_interval` or `Process.send_after` with hardcoded integer intervals
- Test files that use `Process.sleep` to wait for a scheduled message
- GenServers where the interval is read from `Application.get_env` in `init/1`
  (a smell — the test must set app config to control timing)

## Bad

```elixir
defmodule MyApp.Heartbeat do
  use GenServer

  def init(_) do
    :timer.send_interval(30_000, self(), :tick)  # hardcoded, untestable at speed
    {:ok, %{count: 0}}
  end

  def handle_info(:tick, state) do
    {:noreply, %{state | count: state.count + 1}}
  end
end

# Test forced to sleep
test "heartbeat increments on tick" do
  {:ok, pid} = start_supervised(MyApp.Heartbeat)
  Process.sleep(30_100)  # wait for the first tick — slow and brittle
  state = :sys.get_state(pid)
  assert state.count == 1
end
```

## Good

```elixir
defmodule MyApp.Heartbeat do
  use GenServer

  def start_link(opts \\ []) do
    interval = Keyword.get(opts, :interval, 30_000)
    GenServer.start_link(__MODULE__, interval, Keyword.take(opts, [:name]))
  end

  def init(interval) do
    if interval > 0, do: Process.send_after(self(), :tick, interval)
    {:ok, %{count: 0, interval: interval}}
  end

  def handle_info(:tick, state) do
    if state.interval > 0, do: Process.send_after(self(), :tick, state.interval)
    {:noreply, %{state | count: state.count + 1}}
  end

  def tick_count(pid), do: GenServer.call(pid, :tick_count)
  def handle_call(:tick_count, _from, state), do: {:reply, state.count, state}
end

# In tests: inject interval: 0 and send ticks manually
test "heartbeat increments on manual tick" do
  {:ok, pid} = start_supervised({MyApp.Heartbeat, interval: 0})
  send(pid, :tick)
  assert MyApp.Heartbeat.tick_count(pid) == 1
end
```

## When This Applies

- GenServers with periodic `handle_info` callbacks driven by timers
- Polling processes that check external state on an interval
- Cache-expiry, health-check, or metric-flush processes

## When This Does Not Apply

- Integration tests that specifically test timing behaviour (e.g., ensuring
  expiry actually happens after N milliseconds in production conditions)
- Processes where the interval itself is the thing under test

## Further Reading

- [Elixir docs — Process.send_after/3](https://hexdocs.pm/elixir/Process.html#send_after/3)
- [Saša Jurić — "Elixir in Action" Chapter 7: Building a concurrent system](https://www.manning.com/books/elixir-in-action)
- [Testing Elixir (Pragmatic) — Chapter on time-dependent tests](https://pragprog.com/titles/lmelixir/testing-elixir/)
