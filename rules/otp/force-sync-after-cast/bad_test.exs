# EXPECTED: passes
# BAD PRACTICE: Uses Process.sleep after GenServer.cast to "wait" for the
# cast to be processed. This is a race condition — the sleep may be too short
# under load or in CI, causing intermittent failures. It also makes the test
# suite artificially slower. The fix is to use a synchronous call instead.
Mix.install([])

ExUnit.start(autorun: true)

Code.require_file("support.ex", __DIR__)

defmodule OTP003Bad.ForceSyncBadTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = GenServer.start_link(OTP003.EventLog, [])
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{log: pid}
  end

  test "log_event records a single event (fragile sleep)", %{log: log} do
    OTP003.EventLog.log_event(log, :user_signup)
    # Sleep introduces a race: may be too short under load, too long normally
    Process.sleep(10)
    assert OTP003.EventLog.get_events(log) == [:user_signup]
  end

  test "multiple casts recorded (fragile sleep)", %{log: log} do
    OTP003.EventLog.log_event(log, :login)
    OTP003.EventLog.log_event(log, :page_view)
    # Sleeping after casts — could miss messages if the process is busy
    Process.sleep(10)
    events = OTP003.EventLog.get_events(log)
    assert events == [:login, :page_view]
  end
end
