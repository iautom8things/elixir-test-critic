---
id: ETC-OTP-003
title: "Force synchronization after GenServer.cast"
category: otp
severity: warning
summary: >
  After issuing a GenServer.cast, call a synchronous operation to force the
  process to drain its mailbox before asserting. Never use Process.sleep to
  wait for a cast to be processed.
principles:
  - assert-not-sleep
applies_when:
  - "A test sends a cast and then asserts on some observable side effect"
  - "The side effect is only visible after the GenServer processes its mailbox"
related_rules:
  - ETC-CORE-006
---

# Force synchronization after GenServer.cast

`GenServer.cast/2` is asynchronous — it enqueues a message and returns
immediately. If you assert right after a cast, you may assert before the
GenServer has processed the message. The fix is not `Process.sleep` — it
is a synchronous call that forces the GenServer to process its mailbox first.

## Problem

`Process.sleep` introduces a race condition and a performance tax. It races
because the system can always be slower than the sleep duration under load,
in CI, or on a slow machine. It taxes the suite because every sleeping test
adds real wall-clock time regardless of how fast the underlying work is.

The correct technique: issue a `GenServer.call` after the cast. Because calls
are processed in mailbox order and are synchronous, by the time the call
returns, all prior casts have been processed. A no-op call like `:flush` or
`:ping` works perfectly; so does any existing read operation.

## Detection

- `Process.sleep` anywhere after a `GenServer.cast` or `send`
- `:timer.sleep` after a cast
- A comment explaining "wait for the cast to be processed"

## Bad

```elixir
test "log_event records the event" do
  {:ok, pid} = start_supervised(MyApp.EventLog)
  MyApp.EventLog.log_event(pid, :user_signup)
  Process.sleep(50)  # hoping the cast was processed
  assert MyApp.EventLog.get_events(pid) == [:user_signup]
end
```

## Good

```elixir
test "log_event records the event" do
  {:ok, pid} = start_supervised(MyApp.EventLog)
  MyApp.EventLog.log_event(pid, :user_signup)
  # A synchronous call forces the GenServer to process its mailbox first
  MyApp.EventLog.flush(pid)
  assert MyApp.EventLog.get_events(pid) == [:user_signup]
end
```

## When This Applies

- Any test that calls `GenServer.cast` and then asserts on the result
- Tests that use `send(pid, message)` directly and need to observe the effect
- Tests using `Kernel.send/2` to simulate incoming messages

## When This Does Not Apply

- When the cast itself triggers a message back to the test process; use
  `assert_receive` instead
- When you are testing `handle_info` callbacks triggered by external events;
  `assert_receive` is the right tool

## Further Reading

- [ExUnit — assert_receive](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_receive/3)
- [Elixir docs — GenServer.cast/2](https://hexdocs.pm/elixir/GenServer.html#cast/2)
- [Saša Jurić — "The Soul of Erlang and Elixir" (keynote)](https://www.youtube.com/watch?v=JvBT4XBdoUE)
