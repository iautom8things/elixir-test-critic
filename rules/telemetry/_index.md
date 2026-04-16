# Telemetry — Instrumenting and Asserting Events

## Scope

Rules in this category cover how to write correct and reliable tests for code
that emits `:telemetry` events. They apply to any Elixir project that uses the
`:telemetry` library — including projects built on Phoenix, Ecto, Oban, Finch,
or any other library that emits telemetry events, as well as applications that
emit their own custom events.

Telemetry events have two important characteristics that shape how tests should
be written:

1. **Dispatch is synchronous.** `:telemetry.execute/3` calls every attached
   handler inline, in the calling process, before returning. This means events
   are delivered before the next line of test code runs — no waiting required.

2. **Handlers are global.** The handler registry is a VM-wide ETS table.
   Handlers persist until explicitly removed. Leaked handlers affect subsequent
   tests and can cause mysterious duplicate-dispatch failures.

Telemetry rules address: using the official test helper, choosing the right
assertion macro, cleaning up after handlers, and writing assertions that remain
valid across environments.

## Rules

| ID | Slug | Title | Severity |
|----|------|-------|----------|
| ETC-TELE-001 | use-telemetry-test | Use :telemetry_test.attach_event_handlers/2 | recommendation |
| ETC-TELE-002 | assert-received-for-sync | Use assert_received for synchronous telemetry events | warning |
| ETC-TELE-003 | detach-handlers | Always detach telemetry handlers after tests | warning |
| ETC-TELE-004 | test-shape-not-values | Assert event shape, not exact measurement values | warning |
