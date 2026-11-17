# EXPECTED: passes
# BAD PRACTICE: Agent started with bare start_link, outside ExUnit's supervisor.
# The agent dies only after the test process exits and nothing waits for it. In a
# real suite with named processes, the next test can start first and crash with
# {:already_started, pid}. This script passes because its agents are unnamed.
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
    # Wrong: bare start_link. Nothing stops this before the next test starts.
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
