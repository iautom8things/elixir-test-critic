---
id: ETC-CORE-006
title: "Use start_supervised for process cleanup"
category: core
severity: critical
summary: >
  Start processes in tests using `start_supervised!/2` so ExUnit automatically
  shuts them down after the test completes. Manual `GenServer.start_link` without
  supervision leaks processes between tests, causing interference and flakiness.
principles:
  - async-default
  - thin-processes
related_rules:
  - ETC-OTP-003
applies_when:
  - "Any test that starts a GenServer, Agent, Task, or other long-lived process"
  - "Any test that needs a supervised process that should not outlive the test"
does_not_apply_when:
  - "Testing the start_link function itself — you need the raw result to assert on the pid/error"
  - "Testing process registration under specific names — start_supervised may conflict with name registration tests"
---

# Use start_supervised for process cleanup

`start_supervised!/2` registers the started process with ExUnit's test supervisor.
When the test ends — whether it passes, fails, or raises — ExUnit stops the process.
Processes started with bare `GenServer.start_link` or `Agent.start_link` are not
cleaned up automatically and continue running until the VM exits or crashes.

## Problem

When a test starts a process without supervision, that process outlives the test.
The next test may encounter the leftover process:

- If two tests start a process registered under the same name, the second test
  crashes with `{:error, {:already_started, pid}}`
- Leaked processes accumulate state that bleeds into later tests
- In async test runs, leaked processes from one test can receive messages from
  another test's operations, causing inexplicable failures

These bugs are notoriously hard to diagnose because the failing test is not the
one that created the problem.

## Detection

- `GenServer.start_link` or `Agent.start_link` in test body or setup without `start_supervised`
- `{:ok, pid} = MyServer.start_link(...)` in a test (should be `start_supervised!(MyServer, ...)`)
- Missing `on_exit` cleanup for processes started with `start_link`

## Bad

```elixir
setup do
  {:ok, pid} = MyCache.start_link([])
  %{cache: pid}
  # Process leaks when the test ends — next test may find it running
end
```

## Good

```elixir
setup do
  pid = start_supervised!(MyCache)
  %{cache: pid}
  # ExUnit stops MyCache after this test, regardless of pass/fail
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
- [Saša Jurić — "Testing concurrent Elixir code"](https://www.erlang-in-anger.com/)
