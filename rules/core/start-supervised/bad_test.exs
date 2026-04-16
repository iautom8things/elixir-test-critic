# EXPECTED: passes
# BAD PRACTICE: Agent started with bare start_link — not registered with ExUnit's
# supervisor. The agent leaks after each test and accumulates in the VM. In a real
# test suite with named processes, this causes {:already_started, pid} crashes in
# later tests.
Mix.install([])

ExUnit.start(autorun: true)

defmodule StartSupervisedBadAgent do
  use Agent

  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end)
  end

  def get(pid), do: Agent.get(pid, & &1)
  def put(pid, value), do: Agent.update(pid, fn _ -> value end)
end

defmodule StartSupervisedBadTest do
  use ExUnit.Case, async: true

  setup do
    # Wrong: bare start_link without start_supervised — process leaks after test
    {:ok, pid} = StartSupervisedBadAgent.start_link(nil)
    %{agent: pid}
  end

  test "agent starts with nil", %{agent: pid} do
    assert StartSupervisedBadAgent.get(pid) == nil
  end

  test "agent stores a value", %{agent: pid} do
    StartSupervisedBadAgent.put(pid, 42)
    assert StartSupervisedBadAgent.get(pid) == 42
  end
end
