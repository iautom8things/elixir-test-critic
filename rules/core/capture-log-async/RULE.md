---
id: ETC-CORE-008
title: "Use pattern matching with capture_log in async tests"
category: core
severity: warning
summary: >
  When asserting on log output in async tests, use `=~` (substring match) rather
  than `==` (exact match) with `capture_log`. Spawned processes within the test may
  emit logs after the capture window closes, making the exact string unpredictable.
principles:
  - async-default
applies_when:
  - "Any async test that uses ExUnit.CaptureLog.capture_log/1"
  - "Tests where the code under test spawns Tasks, GenServers, or other processes that may log"
---

# Use pattern matching with capture_log in async tests

`ExUnit.CaptureLog.capture_log/1` captures logs emitted synchronously during the
captured function's execution. In async tests, processes spawned inside the captured
function may continue logging after the capture window closes, or logs from concurrent
tests may appear in the captured output. Assert on the presence of key substrings
rather than the exact full string.

## Problem

`capture_log` captures log messages that arrive at the Logger backend during the
execution of the captured function. The issue in async tests has two dimensions:

1. **Spawned process timing**: if the code under test spawns a process (Task, GenServer)
   that logs asynchronously, those messages may arrive after `capture_log` returns.
   The captured string may be missing expected messages, or contain extra messages
   depending on timing.

2. **Exact string fragility**: even in synchronous scenarios, asserting `log == "expected"`
   is brittle because the Logger may add metadata (timestamps, PID, level) depending on
   backend configuration. The key insight is the MESSAGE CONTENT you care about, not the
   full formatted log line.

Using `=~` or `String.contains?` asserts that the important part of the log is present
without requiring a full exact match.

## Detection

- `assert capture_log(...) == "exact string"` in any async test
- `capture_log` in a test that calls code which spawns processes or uses `Task.async`
- `assert captured_log == expected_log` (exact equality on a captured log string)

## Bad

```elixir
test "logs the user id on creation" do
  log = capture_log(fn ->
    MyApp.create_user(%{name: "Alice"})
  end)
  # Fragile: exact match fails if Logger adds metadata or a spawned process logs extra
  assert log == "[info] Created user 1"
end
```

## Good

```elixir
test "logs the user id on creation" do
  log = capture_log(fn ->
    MyApp.create_user(%{name: "Alice"})
  end)
  # Robust: check that the important part appears anywhere in the captured output
  assert log =~ "Created user"
end
```

## When This Applies

- Async tests using `capture_log` regardless of whether spawning is involved — the
  `=~` style is safer and costs nothing
- Tests where the captured code calls any library that may add its own log lines

## When This Does Not Apply

- Synchronous tests (`async: false`) where the log output is fully deterministic and
  no external processes can interfere — exact matching is acceptable but still fragile
  to Logger configuration changes
- Tests that explicitly want to assert no stray messages appear (use `refute log =~ "error"`)

## Further Reading

- [ExUnit.CaptureLog docs](https://hexdocs.pm/ex_unit/ExUnit.CaptureLog.html)
- [Logger — capturing logs in tests](https://hexdocs.pm/logger/Logger.html)
