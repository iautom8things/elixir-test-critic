# EXPECTED: passes
# BAD PRACTICE: assert_received used after spawning an async process.
# This test passes when the spawned process wins the scheduler race, and fails
# on slow or loaded systems. ExUnit cannot detect this race; it just sometimes fails.
Mix.install([])

ExUnit.start(autorun: true)

defmodule AssertReceiveVsReceivedBadTest do
  use ExUnit.Case, async: true

  test "flaky: assert_received on an async message" do
    test_pid = self()
    # The spawned process runs concurrently — message may not arrive before assert_received checks
    spawn(fn ->
      # Yield to make message delivery less likely to win the race, but this is still racy
      Process.sleep(0)
      send(test_pid, :async_done)
    end)
    # Wrong: no timeout — will race with the spawned process
    # We add Process.sleep here just to make the demo pass reliably; in real code
    # developers often rely on luck or add Process.sleep, both of which are wrong.
    Process.sleep(50)
    assert_received :async_done
  end
end
