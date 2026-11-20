# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule ReceiveTimeoutBudgetGoodTest do
  use ExUnit.Case, async: true

  test "receives the worker result" do
    parent = self()
    spawn(fn -> send(parent, {:done, 42}) end)
    assert_receive {:done, 42}, 1_000
  end
end
