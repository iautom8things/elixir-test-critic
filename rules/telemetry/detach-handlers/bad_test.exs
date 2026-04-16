# EXPECTED: passes
# This test passes but demonstrates the discouraged pattern:
# attaching a handler without registering on_exit cleanup.
# The handler leaks globally after this test process exits.
Mix.install([:telemetry])

ExUnit.start(autorun: true)

defmodule TELE003.BadTest do
  use ExUnit.Case, async: true

  test "attaches handler but forgets to detach — handler leaks globally" do
    test_pid = self()

    # BAD: no on_exit — this handler outlives the test
    :telemetry.attach(
      "tele003-leaked-handler",
      [:tele003, :bad, :event],
      fn _event, measurements, _meta, _cfg ->
        # Once the test process exits, send/2 to a dead pid raises; other tests
        # attaching to the same event will also trigger this stale handler.
        send(test_pid, {:got_event, measurements})
      end,
      nil
    )

    :telemetry.execute([:tele003, :bad, :event], %{count: 1}, %{})

    assert_received {:got_event, %{count: 1}}

    # Manual cleanup here only — would be missing in a real bad example,
    # but we clean up to avoid polluting the test runner environment.
    :telemetry.detach("tele003-leaked-handler")
  end
end
