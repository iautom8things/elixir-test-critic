# EXPECTED: passes
Mix.install([:telemetry])

ExUnit.start(autorun: true)

defmodule TELE004.GoodTest do
  use ExUnit.Case, async: true

  test "asserts duration is a positive integer, not an exact value" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:tele004, :query, :stop]])

    # Simulate a query that took some time — the exact value is irrelevant
    duration = :erlang.monotonic_time() - :erlang.monotonic_time()

    :telemetry.execute(
      [:tele004, :query, :stop],
      %{duration: 500, system_time: System.system_time()},
      %{table: "users", operation: :select}
    )

    assert_received {[:tele004, :query, :stop], ^ref, measurements, metadata}

    # Shape assertions — environment-independent
    assert is_integer(measurements.duration)
    assert measurements.duration >= 0

    assert is_integer(measurements.system_time)
    assert measurements.system_time > 0

    # Metadata is stable under our control — key presence is safe to assert
    assert Map.has_key?(metadata, :table)
    assert Map.has_key?(metadata, :operation)
    assert metadata.table == "users"
    assert metadata.operation == :select

    _ = duration
  end

  test "asserts count is at least the minimum, not exactly N" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:tele004, :batch, :stop]])

    :telemetry.execute([:tele004, :batch, :stop], %{count: 3, errors: 0}, %{worker: :default})

    assert_received {[:tele004, :batch, :stop], ^ref, measurements, _meta}

    # Structural constraint: count should be a non-negative integer
    assert is_integer(measurements.count)
    assert measurements.count >= 0

    # Error count should also be non-negative
    assert measurements.errors >= 0
  end
end
