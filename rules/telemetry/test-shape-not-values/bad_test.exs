# EXPECTED: passes
# This test passes only because WE control the exact values emitted.
# The bad pattern is pinning exact measurement values that would normally vary.
Mix.install([:telemetry])

ExUnit.start(autorun: true)

defmodule TELE004.BadTest do
  use ExUnit.Case, async: true

  test "pins exact duration value — brittle in real code where duration varies" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:tele004, :bad, :stop]])

    # In production code you would NOT control this value —
    # it comes from :erlang.monotonic_time() differences.
    # Pinning it makes the test brittle.
    exact_duration = 1234

    :telemetry.execute(
      [:tele004, :bad, :stop],
      %{duration: exact_duration},
      %{source: "db"}
    )

    # BAD: pins an exact duration. If the upstream code changes how it
    # measures duration (e.g., native units vs microseconds), this breaks.
    assert_received {[:tele004, :bad, :stop], ^ref, %{duration: 1234}, _meta}
  end
end
