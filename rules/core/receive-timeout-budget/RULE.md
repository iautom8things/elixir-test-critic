---
id: ETC-CORE-012
title: "Give cross-process assertions enough time"
category: core
severity: warning
summary: >
  Give cross-process assertions a deadline that tolerates a loaded runner. A successful receive returns as soon as the message arrives.
principles:
  - assert-not-sleep
applies_when:
  - "A test waits for a message that another process may still be working on."
does_not_apply_when:
  - "The message is already synchronized, a short refute is intentional, or the deadline itself is the behavior under test."
enforced_by: credo:Shampoo.Check.ShortReceiveTimeout
---

# Give cross-process assertions enough time

Give cross-process assertions a deadline that tolerates a loaded runner. A successful receive returns as soon as the message arrives.

## Problem

A worker that starts promptly on a laptop may get delayed on shared CI. A short deadline makes the assertion fail even when the worker sends the right message.

## Detection

Look for a short integer timeout on a positive receive assertion or an asynchronous test helper. Also check the suite default for waits without an explicit timeout.

## Bad

```elixir
parent = self()
spawn(fn -> send(parent, {:done, 42}) end)
assert_receive {:done, 42}, 25
```

## Good

```elixir
parent = self()
spawn(fn -> send(parent, {:done, 42}) end)
assert_receive {:done, 42}, 1_000
```

## When This Applies

- A test waits for a message that another process may still be working on.

## When This Does Not Apply

- The message is already synchronized, a short refute is intentional, or the deadline itself is the behavior under test.

## Further Reading

- [ExUnit.Assertions.assert_receive/3](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_receive/3)
