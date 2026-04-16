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
---

# Use assert_receive for async, assert_received for sync

`assert_receive/2` waits up to a configurable timeout for a message to arrive in
the test process mailbox. `assert_received/1` checks the mailbox immediately with
no wait. Using the wrong one causes intermittent failures: `assert_received` fails
on slow machines when the message hasn't arrived yet, and `assert_receive` with an
unnecessary timeout slows fast tests.

## Problem

**Using `assert_received` for async messages:**
The message may not yet be in the mailbox when the assertion runs. The test passes
most of the time on fast machines and fails unpredictably under load, during CI, or
after system slow-down. These are the worst kind of failures — infrequent and
non-reproducible.

**Using `assert_receive` when sync is sufficient:**
Less harmful but misleading. It suggests the message arrival is uncertain when it
is actually guaranteed, and it adds an unnecessary timeout to each test run.

The correct pattern when you need sync-then-assert is to force synchronisation
through the process's own API (e.g., a `GenServer.call/2` to flush its mailbox)
and then use `assert_received`.

## Detection

- `assert_received` immediately after `spawn`, `Task.async`, `send` from another process, or any `cast`
- `assert_receive` after a `GenServer.call` that is known to trigger a synchronous send-back
- `Process.sleep` followed by `assert_received` (replace both with `assert_receive`)

## Bad

```elixir
test "worker sends :done after processing" do
  pid = spawn(fn -> Process.send(self(), :done, []) end)
  # Races with the spawned process — may fail on slow systems
  assert_received :done
end
```

## Good

```elixir
test "worker sends :done after processing" do
  _pid = spawn(fn -> Process.send(self(), :done, []) end)
  # Waits up to 500ms — deterministic regardless of scheduling
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
