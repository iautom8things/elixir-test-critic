# EXPECTED: passes
Mix.install([:telemetry])

ExUnit.start(autorun: true)

defmodule TELE001.GoodTest do
  use ExUnit.Case, async: true

  test "uses :telemetry_test.attach_event_handlers/2 to capture events" do
    ref = :telemetry_test.attach_event_handlers(self(), [[:tele001, :action, :stop]])

    :telemetry.execute([:tele001, :action, :stop], %{duration: 42}, %{source: :test})

    assert_received {[:tele001, :action, :stop], ^ref, %{duration: 42}, %{source: :test}}
  end

  test "ref pin prevents cross-test message collision" do
    ref1 = :telemetry_test.attach_event_handlers(self(), [[:tele001, :ping]])
    ref2 = :telemetry_test.attach_event_handlers(self(), [[:tele001, :ping]])

    :telemetry.execute([:tele001, :ping], %{count: 1}, %{})

    # Both handlers fire; pin the correct ref to select the right message
    assert_received {[:tele001, :ping], ^ref1, %{count: 1}, _}
    assert_received {[:tele001, :ping], ^ref2, %{count: 1}, _}
  end
end
