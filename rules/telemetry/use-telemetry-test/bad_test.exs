# EXPECTED: passes
# This test passes but demonstrates the discouraged pattern:
# manually attaching a handler with send/2 instead of using :telemetry_test.
Mix.install([:telemetry])

ExUnit.start(autorun: true)

defmodule TELE001.BadTest do
  use ExUnit.Case, async: true

  # BAD: hand-rolling a handler with send/2 and a hardcoded handler id.
  # Works, but misses the ref-based disambiguation that attach_event_handlers provides.
  test "manually attaches a handler and uses send to capture events" do
    test_pid = self()
    handler_id = "tele001-bad-handler-#{System.unique_integer()}"

    :telemetry.attach(
      handler_id,
      [:tele001, :bad, :event],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :telemetry.execute([:tele001, :bad, :event], %{latency: 10}, %{resource: "db"})

    assert_received {:telemetry_event, [:tele001, :bad, :event], %{latency: 10}, %{resource: "db"}}
  end
end
