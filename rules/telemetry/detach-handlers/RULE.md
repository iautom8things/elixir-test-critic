---
id: ETC-TELE-003
title: "Always detach telemetry handlers after tests"
category: telemetry
severity: warning
summary: >
  Telemetry handlers are global and persist for the lifetime of the VM. Failing
  to detach a handler after a test leaks it into subsequent tests, causing
  mysterious duplicate event handling, unexpected messages in other tests'
  mailboxes, and hard-to-reproduce failures.
principles:
  - async-default
applies_when:
  - "Tests attach telemetry handlers with :telemetry.attach/4 or :telemetry.attach_many/4"
  - "The handler id is not scoped to the test process lifetime"
  - "Tests do not register cleanup via on_exit or ExUnit teardown"
related_rules:
  - ETC-TELE-001
  - ETC-ISO-001
  - ETC-ISO-003
---

# Always detach telemetry handlers after tests

The `:telemetry` handler registry is a global ETS table. When you call
`:telemetry.attach/4`, the handler lives until explicitly removed with
`:telemetry.detach/1` or until the VM stops. ExUnit does not clean up handlers
between tests automatically.

A leaked handler means every subsequent telemetry event matching that event
name will invoke your stale handler. Depending on what the handler does, this
can:

- Send unexpected messages to a dead test process (causing `send` failures).
- Accumulate in a shared process or ETS table used by later tests.
- Cause double-counting in metrics tests, making them flaky.
- Raise errors because the handler references a closed resource.

## Using on_exit for Cleanup

Always register a cleanup callback with `on_exit` immediately after attaching:

```elixir
handler_id = "my-test-handler-#{System.unique_integer()}"
:telemetry.attach(handler_id, event, handler_fn, nil)
on_exit(fn -> :telemetry.detach(handler_id) end)
```

`on_exit` runs even when the test fails or raises, so cleanup is guaranteed.

## Note on :telemetry_test.attach_event_handlers/2

When you use `:telemetry_test.attach_event_handlers/2`, the helper attaches the
handler with the test process's pid as part of the handler id and automatically
detaches when the test process exits. You do **not** need a manual `on_exit`
call when using this helper — another reason to prefer it over manual attachment.

## Detection

- `:telemetry.attach/4` inside a test or `setup` block without a matching
  `:telemetry.detach/1` in `on_exit` or `on_exit_with_name`.
- Handler ids that are hardcoded atoms or strings without a unique suffix
  (increases the chance of collision and missing cleanup).

## Bad

```elixir
defmodule MyApp.TracingTest do
  use ExUnit.Case, async: true

  test "records a span event" do
    test_pid = self()

    # BAD: no on_exit cleanup — handler leaks to subsequent tests
    :telemetry.attach(
      "tracing-test-handler",
      [:my_app, :span, :stop],
      fn _event, measurements, _meta, _cfg ->
        send(test_pid, {:span_duration, measurements.duration})
      end,
      nil
    )

    :telemetry.execute([:my_app, :span, :stop], %{duration: 300}, %{})

    assert_received {:span_duration, 300}
  end
end
```

## Good

```elixir
defmodule MyApp.TracingTest do
  use ExUnit.Case, async: true

  test "records a span event" do
    test_pid = self()
    handler_id = "tracing-test-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:my_app, :span, :stop],
      fn _event, measurements, _meta, _cfg ->
        send(test_pid, {:span_duration, measurements.duration})
      end,
      nil
    )

    # GOOD: guaranteed cleanup even if the test fails
    on_exit(fn -> :telemetry.detach(handler_id) end)

    :telemetry.execute([:my_app, :span, :stop], %{duration: 300}, %{})

    assert_received {:span_duration, 300}
  end
end
```

## When This Applies

- Any test that calls `:telemetry.attach/4` or `:telemetry.attach_many/4`.
- `setup` blocks that attach handlers shared across multiple tests.

## When This Does Not Apply

- Tests using `:telemetry_test.attach_event_handlers/2` — cleanup is automatic.
- Tests that verify handler behaviour via a real application started under
  supervision (the app's supervision tree manages handler lifecycle).

## Further Reading

- [:telemetry.detach/1 — HexDocs](https://hexdocs.pm/telemetry/telemetry.html#detach/1)
- [ExUnit.Callbacks — on_exit/2](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#on_exit/2)
