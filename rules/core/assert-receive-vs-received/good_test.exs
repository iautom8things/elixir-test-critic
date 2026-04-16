# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule AssertReceiveVsReceivedGoodTest do
  use ExUnit.Case, async: true

  test "assert_receive waits for async message from spawned process" do
    test_pid = self()
    spawn(fn -> send(test_pid, :async_done) end)
    # Correct: wait with a timeout because the message is async
    assert_receive :async_done, 500
  end

  test "assert_received is correct when message is already in mailbox" do
    send(self(), :sync_message)
    # Correct: we sent it ourselves, it's already in the mailbox
    assert_received :sync_message
  end
end
