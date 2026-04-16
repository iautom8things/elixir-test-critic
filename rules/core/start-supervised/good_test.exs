# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule StartSupervisedAgent do
  use Agent

  def start_link(opts \\ []) do
    initial = Keyword.get(opts, :initial, nil)
    Agent.start_link(fn -> initial end)
  end

  def get(pid), do: Agent.get(pid, & &1)
  def put(pid, value), do: Agent.update(pid, fn _ -> value end)
end

defmodule StartSupervisedGoodTest do
  use ExUnit.Case, async: true

  setup do
    # start_supervised! registers the agent with ExUnit's test supervisor.
    # It will be stopped automatically when the test ends.
    pid = start_supervised!(StartSupervisedAgent)
    %{agent: pid}
  end

  test "agent starts with nil", %{agent: pid} do
    assert StartSupervisedAgent.get(pid) == nil
  end

  test "agent stores a value", %{agent: pid} do
    StartSupervisedAgent.put(pid, 42)
    assert StartSupervisedAgent.get(pid) == 42
  end
end
