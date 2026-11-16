---
id: ETC-CORE-004
title: "Use assert_receive for async, assert_received for sync"
category: core
severity: critical
summary: >
  Use `assert_receive/2` (with a timeout) when the message originates from an
  asynchronous operation. Use `assert_received/1` (no timeout, immediate check)
  only when you have already synchronised with the sender and the message is
  guaranteed to be in the mailbox.
principles:
  - assert-not-sleep
applies_when:
  - "When asserting on messages sent by spawned processes, Tasks, GenServers, or PubSub"
  - "When asserting on messages after calling an async function"
  - "When asserting on messages after a synchronous call that guarantees message delivery"
does_not_apply_when:
  - "When the synchronization model is unclear and you need to explore behavior"
related_rules:
  - ETC-BWAY-002
  - ETC-BWAY-003
  - ETC-TELE-002
  - ETC-MOCK-010
  - ETC-CORE-011
---

# Use assert_receive for async, assert_received for sync

`assert_receive/2` waits up to a configurable timeout for a message to arrive in
the test process mailbox. `assert_received/1` checks the mailbox immediately with
no wait. Only one direction of the mix-up is a defect: `assert_received` on a
message that may not have arrived yet fails intermittently. `assert_receive` on a
message that is already there returns at once and costs nothing.

## Problem

**Using `assert_received` for async messages:**
The message may not yet be in the mailbox when the assertion runs. The test passes
most of the time on fast machines and fails unpredictably under load, during CI, or
after system slow-down. These are the worst kind of failures — infrequent and
non-reproducible.

**Using `assert_receive` when sync is sufficient:**
Not a bug, and not slower. `assert_receive` returns as soon as a matching message
is in the mailbox, so a passing test never waits out the timeout. The only costs
are that a failing test waits for the timeout before it reports, and that the
reader cannot tell the delivery was guaranteed. Do not report this as a defect.

The correct pattern when you need sync-then-assert is to force synchronisation
through the process's own API (e.g., a `GenServer.call/2` to flush its mailbox)
and then use `assert_received`.

## Detection

- `assert_received` immediately after `spawn`, `Task.async`, `send` from another process, or any `cast`
- `Process.sleep` followed by `assert_received` (replace both with `assert_receive`)

## Bad

```elixir
test "worker sends :done after processing" do
  test_pid = self()
  spawn(fn -> send(test_pid, :done) end)
  # Races with the spawned process — may fail on slow systems
  assert_received :done
end
```

## Good

```elixir
test "worker sends :done after processing" do
  test_pid = self()
  spawn(fn -> send(test_pid, :done) end)
  # Waits up to 500ms and returns as soon as the message arrives
  assert_receive :done, 500
end
```

## When This Applies

- Any assertion on messages sent by a process other than the test process itself
- Messages sent via `GenServer.cast`, `Task.async`, `Phoenix.PubSub.broadcast`, or `send` from a spawned process

## When This Does Not Apply

- When the synchronization model is unclear and you need to explore behavior — in
  that exploratory phase, using `assert_receive` with a generous timeout is fine
  while you determine the correct synchronization strategy
- `assert_received` is correct after `send(self(), :message)` — the test process
  sent the message itself so it is already in the mailbox

## Further Reading

- [ExUnit.Assertions — assert_receive/3](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_receive/3)
- [ExUnit.Assertions — assert_received/2](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_received/2)
