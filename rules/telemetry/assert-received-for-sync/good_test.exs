# EXPECTED: passes
Mix.install([:telemetry])

ExUnit.start(autorun: true)

defmodule TELE002.GoodTest do
  use ExUnit.Case, async: true

  test "assert_received works immediately after synchronous execute" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:tele002, :request, :stop]])

    # execute/3 is synchronous — handler runs before this line returns
    :telemetry.execute([:tele002, :request, :stop], %{duration: 100}, %{method: "GET"})

    # assert_received: no timeout — the message is already in the mailbox
    assert_received {[:tele002, :request, :stop], ^ref, %{duration: 100}, %{method: "GET"}}
  end

  test "assert_received works for multiple events from a span-like sequence" do
    ref = :telemetry_test.attach_event_handlers(self(), [
      [:tele002, :op, :start],
      [:tele002, :op, :stop]
    ])

    :telemetry.execute([:tele002, :op, :start], %{system_time: System.system_time()}, %{id: 1})
    :telemetry.execute([:tele002, :op, :stop], %{duration: 50}, %{id: 1})

    # Both events are already in the mailbox — no waiting needed
    assert_received {[:tele002, :op, :start], ^ref, _start_meas, %{id: 1}}
    assert_received {[:tele002, :op, :stop], ^ref, %{duration: 50}, %{id: 1}}
  end
end
