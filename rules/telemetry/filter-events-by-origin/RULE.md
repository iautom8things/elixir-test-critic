---
id: ETC-TELE-005
title: "Filter telemetry events by origin in async tests"
category: telemetry
severity: warning
summary: >
  Telemetry handlers are global, so in an async test a handler also receives the
  events that concurrent tests emit. Forward an event only when the emitting
  process is the test or carries it in `$callers`, or a `refute_received` and a
  loose `assert_received` will fail at random.
principles:
  - async-default
  - honest-data
related_rules:
  - ETC-TELE-001
  - ETC-TELE-002
  - ETC-TELE-003
  - ETC-PHX-005
applies_when:
  - "An async: true test attaches a telemetry handler that sends events to the test"
  - "Other tests can emit the same event name concurrently"
  - "The test refutes an event, or asserts on one without pinning a value only it produced"
does_not_apply_when:
  - "The test module is async: false, so nothing else runs while it does"
  - "The event is emitted by a process outside the test's caller chain (a named GenServer); such tests belong in a sync module"
tags: [telemetry, async, flaky, refute_received]
---

# Filter telemetry events by origin in async tests

`:telemetry.attach/4` registers a handler for the whole VM. While an async test
waits, other tests emit the same events, and the handler forwards them too.
Check where an event came from before sending it to the test.

## Problem

A unique handler id keeps two tests' handlers apart. So does the `ref` that
`:telemetry_test.attach_event_handlers/2` returns. Neither keeps tests'
**events** apart. Every attached handler sees every emission of its event
name, whichever test caused it. The two common shapes fail at random:

- `refute_received {:call_event, _, _}` after code that should emit exactly one
  event. A concurrent test's call lands in between, and the refutation fails.
- `assert_received {:call_event, _, %{outcome: :ok}}` matches a stranger's event
  and passes even if the code under test emitted nothing.

One suite saw both. A PM-client test failed on
`%{tool: "list_instances", outcome: :identity_unavailable}`, emitted by a
different test module. A triage-mode test failed on a `{:triage_mode, ...}`
event that some other test caused. Both failures went away on rerun, which is
why they stayed in the suite for weeks.

## Detection

- `use ExUnit.Case, async: true` (or a case template with `async: true`) and
  `:telemetry.attach`, `:telemetry.attach_many` or
  `:telemetry_test.attach_event_handlers` in the same module.
- A handler body that sends unconditionally (`send(test_pid, ...)`) with no
  check on `self()` or `$callers`.
- `refute_received` or `refute_receive` on the forwarded message.

## Bad

```elixir
use ExUnit.Case, async: true

test "a failed call emits one event" do
  test_pid = self()

  :telemetry.attach("call-handler-#{inspect(make_ref())}", [:my_app, :client, :call],
    fn _event, measurements, metadata, _ -> send(test_pid, {:call, measurements, metadata}) end,
    nil)

  assert {:error, :unavailable} = MyApp.Client.call("whoami")
  assert_received {:call, _, %{tool: "whoami"}}
  # Fails whenever another async test calls the client meanwhile.
  refute_received {:call, _, _}
end
```

## Good

```elixir
# test/support/telemetry_helpers.ex
def attach_owned(events, to_message) do
  test_pid = self()
  id = {__MODULE__, test_pid, System.unique_integer()}
  config = %{test_pid: test_pid, to_message: to_message}
  :ok = :telemetry.attach_many(id, events, &__MODULE__.forward_owned/4, config)
  ExUnit.Callbacks.on_exit(fn -> :telemetry.detach(id) end)
end

# A handler runs in the process that emits the event, so self() is the origin.
def forward_owned(event, measurements, metadata, %{test_pid: test_pid, to_message: to_message}) do
  if self() == test_pid or test_pid in Process.get(:"$callers", []) do
    send(test_pid, to_message.(event, measurements, metadata))
  end
end

# In the test
attach_owned([[:my_app, :client, :call]], fn _e, m, md -> {:call, m, md} end)
assert {:error, :unavailable} = MyApp.Client.call("whoami")
assert_received {:call, _, %{tool: "whoami"}}
refute_received {:call, _, _}
```

The filter relies on `:telemetry.execute/3` running handlers inline in the
emitting process. Events from processes started with `Task`, LiveView test
processes and anything else that sets `$callers` pass the filter. Events from a
named GenServer or a supervisor child the test didn't start never arrive. That
failure is loud, not intermittent, and the fix is to move the test to a sync
module.

## When This Applies

- Async tests that capture telemetry, especially with `refute_received`, or
  with `assert_received` patterns that another test could also produce.

## When This Does Not Apply

- **Sync modules**: no other test emits while a sync test runs, apart from
  processes leaked by earlier tests (ETC-ISO-006).
- **Events emitted outside the caller chain**: the filter drops them. Test those
  in a sync module with a plain handler.

## Further Reading

- [:telemetry.execute/3 — handlers run synchronously in the caller](https://hexdocs.pm/telemetry/telemetry.html#execute/3)
- [Task — `$callers`](https://hexdocs.pm/elixir/Task.html#module-ancestor-and-caller-tracking)
