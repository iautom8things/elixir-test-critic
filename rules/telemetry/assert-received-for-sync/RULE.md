---
id: ETC-TELE-002
title: "Use assert_received for synchronous telemetry events"
category: telemetry
severity: recommendation
summary: >
  :telemetry.execute/3 is synchronous — the handler runs inline before execute
  returns. Prefer assert_received (no timeout) over assert_receive: it states
  that delivery is synchronous and fails at once if that stops being true. A
  passing assert_receive is not slower, so this is a clarity preference.
principles:
  - assert-not-sleep
applies_when:
  - "Tests call :telemetry.execute/3 directly and then assert on the emitted event"
  - "The code under test calls :telemetry.execute/3 (not :telemetry.span/3 with async work)"
  - "Tests use assert_receive with a timeout after a synchronous event emission"
related_rules:
  - ETC-TELE-001
  - ETC-CORE-004
  - ETC-CORE-005
  - ETC-TELE-005
  - ETC-TELE-004
---

# Use assert_received for synchronous telemetry events

`:telemetry.execute/3` dispatches events **synchronously**. Every attached
handler runs inline, in the calling process, before `execute` returns. By the
time the next line of your test runs, the handler has already executed and any
`send` it issued has already arrived in the mailbox.

`assert_received` checks the current mailbox without waiting. `assert_receive`
also returns at once when the message is already there, so a passing test pays
nothing for it. The difference shows only in two places:

- **What the test says.** `assert_received` tells the reader the event is emitted
  synchronously. `assert_receive` suggests it might arrive later.
- **What the test catches.** If someone moves the emission into a background
  process, `assert_received` fails at once. `assert_receive` keeps passing and
  hides the change. On failure it also waits out the timeout before reporting.

Neither is a bug. Treat this as a readability preference, not a defect.

## Detection

- `assert_receive` with or without an explicit timeout immediately after
  `:telemetry.execute/3` or after calling code that is known to call
  `:telemetry.execute/3` synchronously.

## Bad

```elixir
defmodule MyApp.MetricsTest do
  use ExUnit.Case, async: true

  test "emits a query event" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:my_app, :repo, :query]])

    MyApp.Repo.query!("SELECT 1")

    # Weaker: the event is already in the mailbox, so this returns at once.
    # But it reads as an async operation, and it would keep passing if the
    # emission later moved to a background process.
    assert_receive {[:my_app, :repo, :query], ^ref, _measurements, _meta}, 200
  end
end
```

## Good

```elixir
defmodule MyApp.MetricsTest do
  use ExUnit.Case, async: true

  test "emits a query event" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:my_app, :repo, :query]])

    MyApp.Repo.query!("SELECT 1")

    # Better: states that the event is emitted before query!/1 returns.
    assert_received {[:my_app, :repo, :query], ^ref, _measurements, _meta}
  end
end
```

## When This Applies

- Direct calls to `:telemetry.execute/3` in tests.
- Library code (Ecto, Finch, etc.) that calls `:telemetry.execute/3` internally
  as part of a synchronous operation.
- `:telemetry.span/3` itself is synchronous — both the `:start` and `:stop`
  events fire before `span` returns.

## When This Does Not Apply

- A background process (e.g., a GenServer) emits the event in a `handle_cast`
  or `handle_info` — the event arrives asynchronously relative to your test.
  In that case, `assert_receive` with a reasonable timeout is correct.

## Further Reading

- [:telemetry.execute/3 — HexDocs](https://hexdocs.pm/telemetry/telemetry.html#execute/3)
- [ExUnit — assert_received/2](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_received/2)
- [ExUnit — assert_receive/3](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_receive/3)
