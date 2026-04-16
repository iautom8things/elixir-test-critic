# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

Code.require_file("support.ex", __DIR__)

defmodule OTP003.ForceSyncGoodTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = GenServer.start_link(OTP003.EventLog, [])
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{log: pid}
  end

  test "log_event records a single event via sync flush", %{log: log} do
    OTP003.EventLog.log_event(log, :user_signup)
    # flush/1 is a GenServer.call — processes all prior casts before returning
    OTP003.EventLog.flush(log)
    assert OTP003.EventLog.get_events(log) == [:user_signup]
  end

  test "multiple casts are all processed before the sync call returns", %{log: log} do
    OTP003.EventLog.log_event(log, :login)
    OTP003.EventLog.log_event(log, :page_view)
    OTP003.EventLog.log_event(log, :logout)
    # get_events/1 is itself a call — ensures all three casts ran first
    events = OTP003.EventLog.get_events(log)
    assert events == [:login, :page_view, :logout]
  end

  test "clear removes all events", %{log: log} do
    OTP003.EventLog.log_event(log, :event_a)
    OTP003.EventLog.flush(log)
    OTP003.EventLog.clear(log)
    assert OTP003.EventLog.get_events(log) == []
  end
end
