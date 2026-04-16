---
id: ETC-TELE-004
title: "Assert event shape, not exact measurement values"
category: telemetry
severity: warning
summary: >
  Telemetry measurement values such as durations and timestamps vary between
  runs. Assert that measurements have the correct keys and that values satisfy
  structural constraints (positive integer, map with required keys) rather than
  asserting exact magnitudes, which produces brittle, environment-dependent tests.
principles:
  - honest-data
  - public-interface
applies_when:
  - "Tests assert on telemetry measurement values that are timing- or system-dependent"
  - "Tests pin exact numeric values for duration, latency, or system_time measurements"
  - "Tests assert metadata equals a specific map rather than checking for required keys"
related_rules:
  - ETC-TELE-001
  - ETC-TELE-002
---

# Assert event shape, not exact measurement values

Telemetry events carry two maps: **measurements** and **metadata**. The
measurement values you care about in tests are usually timing data —
`duration`, `latency`, `system_time` — that inherently vary between machines,
CI environments, and load conditions. Asserting that `duration == 42` will fail
on a slow CI runner even when your code is perfectly correct.

The contract you actually want to verify is:

- The event was emitted at all.
- The measurements map contains the expected keys.
- Numeric values satisfy structural constraints: non-negative, positive integer, etc.
- The metadata map contains the expected keys with the expected types or values
  (metadata is usually static and safe to match exactly).

## What to Assert

| Measurement type | Good assertion | Bad assertion |
|-----------------|----------------|---------------|
| Duration (monotonic units) | `assert meas.duration > 0` | `assert meas.duration == 42` |
| System time | `assert is_integer(meas.system_time)` | `assert meas.system_time == 1_700_000_000` |
| Count / byte size | `assert meas.count >= 1` | `assert meas.count == 3` |
| Metadata key presence | `assert Map.has_key?(meta, :user_id)` | `assert meta == %{user_id: 99}` |

## Detection

- `assert_received` with a measurement map that pins a specific integer for
  duration, latency, or system_time.
- Pattern matches using `%{duration: 42}` or `%{system_time: ^ts}` in telemetry
  assertions.

## Bad

```elixir
defmodule MyApp.InstrumentationTest do
  use ExUnit.Case, async: true

  test "emits stop event with correct duration" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:my_app, :http, :stop]])

    MyApp.HTTP.get("https://example.com/api")

    # BAD: pins an exact duration — will fail on any run that takes a different amount of time
    assert_received {[:my_app, :http, :stop], ^ref, %{duration: 1500}, _meta}
  end
end
```

## Good

```elixir
defmodule MyApp.InstrumentationTest do
  use ExUnit.Case, async: true

  test "emits stop event with a positive duration and expected metadata keys" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:my_app, :http, :stop]])

    MyApp.HTTP.get("https://example.com/api")

    assert_received {[:my_app, :http, :stop], ^ref, measurements, metadata}

    # Assert shape and structural constraints, not exact magnitude
    assert is_integer(measurements.duration)
    assert measurements.duration > 0

    # Metadata keys are stable — asserting their presence is safe
    assert Map.has_key?(metadata, :url)
    assert Map.has_key?(metadata, :status)
  end
end
```

## When This Applies

- Any telemetry event that carries timing data (duration, latency, system_time).
- Events where measurement values depend on external factors (network, I/O, CPU).
- Metadata assertions that go beyond key presence when the exact value is dynamic.

## When This Does Not Apply

- Measurement values that your own code computes and controls entirely, where
  asserting an exact value tests the computation logic (e.g., a counter you
  increment by 1).
- Metadata fields that are constants under test control (e.g., `%{env: :test}`).

## Further Reading

- [:telemetry — Measurements and Metadata](https://hexdocs.pm/telemetry/telemetry.html)
- [Elixir — Map.has_key?/2](https://hexdocs.pm/elixir/Map.html#has_key?/2)
