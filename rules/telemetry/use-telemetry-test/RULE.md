---
id: ETC-TELE-001
title: "Use :telemetry_test.attach_event_handlers/2"
category: telemetry
severity: recommendation
summary: >
  Use the official :telemetry_test.attach_event_handlers/2 helper to capture
  telemetry events in tests. It ships with the :telemetry package, returns a
  reference for message matching, and formats messages consistently as
  {event, ref, measurements, metadata}.
principles:
  - public-interface
  - assert-not-sleep
applies_when:
  - "Tests need to assert that telemetry events are emitted"
  - "Tests use :telemetry.attach/4 manually to capture events"
  - "Tests spin up custom handler functions to record events"
related_rules:
  - ETC-TELE-002
  - ETC-TELE-003
  - ETC-TELE-004
---

# Use :telemetry_test.attach_event_handlers/2

The `:telemetry` package ships a test helper module, `:telemetry_test`, that
provides the `attach_event_handlers/2` function. This is the idiomatic way to
capture telemetry events in ExUnit tests. Using it avoids hand-rolled handler
functions, provides consistent message formatting, and yields a reference that
lets you match messages precisely even when multiple tests run concurrently.

## Why the Official Helper

`attach_event_handlers/2` does three things automatically:

1. Attaches a handler that sends a message to the calling test process.
2. Returns a `ref` you include in pattern matches so messages from different
   test setups do not collide.
3. Formats every message as `{event_name, ref, measurements, metadata}`, giving
   you a stable shape to assert against.

When you write your own handler you must solve all three problems yourself, and
you risk subtle bugs — wrong process target, missing cleanup, inconsistent shape.

## Detection

- `:telemetry.attach/4` called inside a test file with an anonymous handler that
  uses `send(self(), …)` — prefer `attach_event_handlers/2` instead.
- Custom accumulator agents or process dictionaries used to capture event data
  in tests.

## Bad

```elixir
defmodule MyApp.MetricsTest do
  use ExUnit.Case, async: true

  test "emits a purchase event" do
    test_pid = self()

    :telemetry.attach(
      "test-handler",
      [:my_app, :purchase, :complete],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    MyApp.Checkout.purchase(%{item: "book", price: 999})

    assert_received {:telemetry_event, [:my_app, :purchase, :complete], %{count: 1}, _meta}

    :telemetry.detach("test-handler")
  end
end
```

## Good

```elixir
defmodule MyApp.MetricsTest do
  use ExUnit.Case, async: true

  test "emits a purchase event" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:my_app, :purchase, :complete]])

    MyApp.Checkout.purchase(%{item: "book", price: 999})

    assert_received {[:my_app, :purchase, :complete], ^ref, %{count: 1}, _meta}
  end
end
```

The `^ref` pin ensures the message belongs to this test's handler, not a
handler attached by a concurrent test. Cleanup is handled automatically when
the test process exits (the handler is attached to the test pid's lifetime).

## When This Applies

- Any test that verifies a telemetry event is emitted.
- Integration tests that instrument library calls (Ecto queries, HTTP requests,
  etc.) that emit telemetry events.

## When This Does Not Apply

- Production handler code (not tests) that reacts to events.
- Tests that deliberately test custom handler logic (you would attach your real
  handler, not `attach_event_handlers/2`).

## Further Reading

- [:telemetry_test — HexDocs](https://hexdocs.pm/telemetry/telemetry_test.html)
- [:telemetry.attach/4 — HexDocs](https://hexdocs.pm/telemetry/telemetry.html#attach/4)
