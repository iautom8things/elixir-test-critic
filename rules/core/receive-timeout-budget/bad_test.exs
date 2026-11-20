# EXPECTED: passes
# BAD PRACTICE: Allow only 25 ms for another process to send a message.
Mix.install([])

ExUnit.start(autorun: true)

defmodule ReceiveTimeoutBudgetBadTest do
  use ExUnit.Case, async: true

  test "receives the worker result" do
    parent = self()
    spawn(fn -> send(parent, {:done, 42}) end)
    assert_receive {:done, 42}, 25
  end
end
