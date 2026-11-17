# EXPECTED: passes
# This test passes but demonstrates the discouraged pattern:
# using assert_receive with a timeout for a synchronous telemetry event.
# It passes at once, but reads as async and would hide a move to async emission.
Mix.install([:telemetry])

ExUnit.start(autorun: true)

defmodule TELE002.BadTest do
  use ExUnit.Case, async: true

  test "uses assert_receive with timeout for a synchronous event (works, but reads as async)" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:tele002, :bad, :stop]])

    # execute/3 is synchronous — message is in the mailbox before the next line
    :telemetry.execute([:tele002, :bad, :stop], %{duration: 77}, %{label: "x"})

    # BAD: assert_receive with 500 ms timeout — the message is already here.
    # It returns at once. It misleads readers, and a failure waits 500 ms.
    assert_receive {[:tele002, :bad, :stop], ^ref, %{duration: 77}, _meta}, 500
  end
end
