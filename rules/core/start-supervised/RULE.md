---
id: ETC-CORE-006
title: "Use start_supervised for process cleanup"
category: core
severity: critical
summary: >
  Start processes in tests using `start_supervised!/2` so ExUnit stops them, in
  order, before the next test starts. A process started with a bare `start_link`
  only dies some time after the test process exits, and one started unlinked or
  under another supervisor does not die at all.
principles:
  - async-default
  - thin-processes
related_rules:
  - ETC-OTP-003
  - ETC-ISO-006
applies_when:
  - "Any test that starts a GenServer, Agent, Task, or other long-lived process"
  - "Any test that needs a supervised process that should not outlive the test"
does_not_apply_when:
  - "Testing the start_link function itself — you need the raw result to assert on the pid/error"
  - "Testing process registration under specific names — start_supervised may conflict with name registration tests"
---

# Use start_supervised for process cleanup

`start_supervised!/2` starts the process under ExUnit's test supervisor. When the
test ends, whether it passes, fails, or raises, ExUnit stops the process and waits
for it to be gone before the next test starts. Children stop in the reverse of
their start order.

A bare `GenServer.start_link` or `Agent.start_link` gives a weaker guarantee. The
process is linked to the test process, so it does die when the test process exits.
But nothing waits for it:

## Problem

- The exit signal is asynchronous. The next test can start while the old process
  is still alive. If both register the same name, the second test crashes with
  `{:error, {:already_started, pid}}`, and only on some runs.
- Nothing orders the shutdown. A process that depends on another can outlive it
  for a moment and log errors or crash during teardown.
- `on_exit` callbacks run after the test process has exited, so a callback that
  calls the process races its death.
- A process started with `start` instead of `start_link`, started from a spawned
  process, or started under an application supervisor is not linked to the test
  at all. It lives until something stops it (see ETC-ISO-006).

These bugs are notoriously hard to diagnose because the failing test is not the
one that created the problem.

## Detection

- `GenServer.start_link` or `Agent.start_link` in test body or setup without `start_supervised`
- `{:ok, pid} = MyServer.start_link(...)` in a test (should be `start_supervised!(MyServer, ...)`)
- Missing `on_exit` cleanup for processes started with `start_link`
- `on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)`: the
  process can die between the check and the stop, and `GenServer.stop/3` then
  exits the callback with `:noproc`. `start_supervised!` handles a child that
  is already gone.
- A process the code under test starts under an application supervisor is out
  of `start_supervised`'s reach; see ETC-ISO-006

## Bad

```elixir
setup do
  {:ok, pid} = MyCache.start_link([])
  %{cache: pid}
  # Dies only after the test process exits. Nothing waits for it, so the next
  # test can start while it is still running.
end
```

## Good

```elixir
setup do
  pid = start_supervised!(MyCache)
  %{cache: pid}
  # ExUnit stops MyCache and waits for it before the next test, pass or fail
end
```

## When This Applies

- Any process started in `setup`, `setup_all`, or the test body that should not
  outlive the test
- Named processes are especially important to supervise — name conflicts between
  tests are a common source of mysterious failures

## When This Does Not Apply

- **Testing `start_link` directly**: if the test's subject IS the process startup
  (e.g., `assert {:error, :already_started} = MyServer.start_link(name: :dup)`),
  you need the raw call result and cannot use `start_supervised`
- **Testing name registration conflicts**: if you deliberately start two processes
  with the same name to test the conflict behavior, `start_supervised` may interfere

## Further Reading

- [ExUnit.Callbacks — start_supervised/2](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#start_supervised/2)
- [ExUnit.Callbacks — start_supervised!/2](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#start_supervised!/2)
