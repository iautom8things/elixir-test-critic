---
id: ETC-CORE-011
title: "Keep setup work outside the deadline a test proves"
category: core
severity: warning
summary: >
  A test that proves a timeout should block at the first step the budget covers,
  not after a handshake that shares the budget. Otherwise a loaded CI runner
  spends the budget before the blocking step is reached, and the test fails
  for a reason that has nothing to do with the timeout.
principles:
  - assert-not-sleep
  - honest-data
related_rules:
  - ETC-CORE-004
  - ETC-OTP-006
applies_when:
  - "A test passes a small deadline, timeout or budget (tens to hundreds of ms) to the code under test"
  - "The code under test does other work (handshakes, init requests, file reads, encoding) inside that budget before the step the test blocks"
  - "The test asserts that the blocking step was reached, or that it was killed"
does_not_apply_when:
  - "The budget is driven by an injected clock rather than wall time"
  - "The blocking step is the first thing inside the budget"
tags: [timeout, deadline, ci, flaky, load]
---

# Keep setup work outside the deadline a test proves

To prove that a deadline stops an in-flight call, block the call at the first
step the deadline covers and leave the budget plenty of margin. Never let the
budget pay for setup that a slow machine can stretch past it.

## Problem

A client often does several things inside one budget: an initialize request, a
notification, then the real call. A test of the deadline stubs the real call to
block forever and sets a small budget so the test stays fast:

```elixir
server(fn _conn, _ -> send(owner, {:blocked, self()}); receive do: (:never -> :never) end)
assert {:error, :timeout, %{}} = call(deadline_ms: 100)
assert_received {:blocked, pid}
```

On a quiet laptop the first two requests take a few milliseconds. On a busy CI
runner, with coverage on and other tests competing for the CPU, they can take
the whole 100 ms. Then the deadline fires before the real call is sent. The
handler never runs, `{:blocked, pid}` is never sent, and the assertion fails
with `no matching message after 0ms`.

Under one busy process per core, one suite measured the real call arriving at
p50 88 ms and p99 208 ms. 30% of calls missed a 100 ms budget. The first
request arrived at p99 2.3 ms. Raising the `assert_received` timeout would not
have helped, because the message was never sent.

## Detection

- A literal `deadline_ms:`, `timeout:` or `budget` under about 500 ms passed to
  the code under test.
- A stub that blocks on a later step (tools/call, the second request, the
  commit) while earlier steps share the same budget.
- An assertion that the blocking step was reached (`assert_received
  {:blocked, _}`) right after the deadline result.
- Failures only on CI, with "no matching message" on a message the stub sends.

## Bad

```elixir
test "a deadline kills the in-flight call" do
  owner = self()

  # Blocks only the third request; the first two share the 100 ms budget.
  stub(fn
    :call -> send(owner, {:blocked, self()}); receive do: (:never -> :never)
    _setup_step -> :ok
  end)

  assert {:error, :timeout} = Client.call(stub, deadline_ms: 100)
  assert_received {:blocked, pid}
  refute Process.alive?(pid)
end
```

## Good

```elixir
test "a deadline kills the in-flight call" do
  owner = self()

  # Blocks the first request, so only the task's start sits inside the budget.
  stub(fn _any_step -> send(owner, {:blocked, self()}); receive do: (:never -> :never) end)

  assert {:error, :timeout} = Client.call(stub, deadline_ms: 1_000)
  assert_received {:blocked, pid}
  refute Process.alive?(pid)
end
```

Size the budget from a measurement under load, not from a quiet laptop. Run the
code under test while one busy process per core runs inside the same machine or
container, and take the worst case of what is left inside the budget. A blocked
test pays the whole budget in wall time, but an async test pays it in one slot
of `max_cases`, so 1 s costs little and buys a large margin.

## When This Applies

- Deadline, timeout and budget tests where the code under test does work of its
  own before reaching the step the test blocks.
- Tests that hibernate, warm up or expire after a short window and assert on
  state just past it.

## When This Does Not Apply

- **Injected clocks**: if the deadline is computed from a clock the test
  controls, wall time doesn't matter.
- **Blocking at the first step**: once the budget covers only the task's start,
  a modest budget is safe.

## Further Reading

- [Task.yield/2 and Task.shutdown/2](https://hexdocs.pm/elixir/Task.html#yield/2)
- [ExUnit.Assertions — assert_received](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_received/2)
