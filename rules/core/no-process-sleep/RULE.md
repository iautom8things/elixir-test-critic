---
id: ETC-CORE-005
title: "Never use Process.sleep for synchronization"
category: core
severity: critical
summary: >
  Do not use `Process.sleep/1` to wait for asynchronous operations to complete.
  It creates timing-dependent tests that are flaky under load and arbitrarily slow
  on fast machines. Use `assert_receive`, `GenServer.call`, or process monitoring instead.
principles:
  - assert-not-sleep
applies_when:
  - "Any test that starts an async operation and then asserts on its side effects"
  - "Any test that waits for a message, a state change, or a side effect in another process"
does_not_apply_when:
  - "Deliberate timing tests for rate limiters or debounce logic where sleep IS the behavior under test"
related_rules:
  - ETC-TELE-002
---

# Never use Process.sleep for synchronization

`Process.sleep/1` pauses the current process for a wall-clock duration. When used
to wait for another process to complete work, it creates a race: the sleep might
end before the other process finishes, failing unpredictably; or the sleep is far
too long, wasting time on every run.

## Problem

`Process.sleep` for synchronisation has two failure modes:

1. **Too short**: the sleeping duration is shorter than the work takes under load,
   causing intermittent CI failures that are hard to reproduce locally.
2. **Too long**: the duration is padded for safety, adding seconds to the test suite
   with no benefit on machines where the work completes in milliseconds.

Both problems compound as the codebase grows. A test suite with 50 tests each
sleeping 100ms has 5 seconds of pure wait time — before any actual test work.

The root cause is always the same: the test is trying to synchronise with an
asynchronous operation by guessing a duration rather than receiving confirmation.

## Detection

- `Process.sleep(N)` anywhere in a test body (except the `does_not_apply_when` cases)
- `Process.sleep` followed by an assertion that checks state in another process
- `Process.sleep` followed by `assert_received`
- Comments like `# wait for the GenServer to process` above a sleep

## Bad

```elixir
test "counter increments" do
  {:ok, pid} = Counter.start_link(0)
  Counter.increment(pid)          # async cast
  Process.sleep(100)               # hope 100ms is enough
  assert Counter.value(pid) == 1  # sometimes fails on slow CI
end
```

## Good

```elixir
test "counter increments" do
  {:ok, pid} = Counter.start_link(0)
  Counter.increment(pid)           # async cast
  # Force synchronization: the call can't return until the cast is processed
  assert Counter.value(pid) == 1
end
```

Or if the operation is message-based:

```elixir
test "worker notifies completion" do
  test_pid = self()
  Worker.process_async(test_pid)
  assert_receive {:done, _result}, 1000
end
```

## When This Applies

- Tests that start GenServers, Tasks, or any async operation and assert on results
- Tests that use `Phoenix.PubSub`, `Registry`, or any pub/sub mechanism
- Tests that cast to a GenServer and check its state

## When This Does Not Apply

- **Rate limiter tests**: verifying that a rate limiter allows N requests per second
  requires actual wall-clock time; `Process.sleep` is testing the behavior directly
- **Debounce tests**: verifying that debounced functions do not fire until a quiet
  period has elapsed requires sleeping through that period
- **Deliberate delay tests**: testing retry backoff, TTL expiry, or scheduled jobs
  where the sleep IS the system under test

## Further Reading

- [ExUnit.Assertions — assert_receive/3](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_receive/3)
- [José Valim — "No more Process.sleep in tests"](https://elixir-lang.org/blog/2019/02/25/mint-a-new-http-client-for-elixir/)
- [Saša Jurić — "The soul of Erlang and Elixir" (synchronization patterns)](https://www.youtube.com/watch?v=JvBT4XBdoUE)
