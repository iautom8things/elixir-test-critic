# EXPECTED: passes
# BAD PRACTICE: A named Agent starts outside ExUnit's supervisor.
# ExUnit does not wait for the Agent to stop. A later test reusing the name
# could fail with {:already_started, pid}. Only one test starts it here.
Mix.install([])

ExUnit.start(autorun: true)

defmodule StartSupervisedBadAgent do
  use Agent

  def start_link(opts) do
    {initial, opts} = Keyword.pop(opts, :initial)
    Agent.start_link(fn -> initial end, opts)
  end

  def get(pid), do: Agent.get(pid, & &1)
  def put(pid, value), do: Agent.update(pid, fn _ -> value end)
end

defmodule StartSupervisedBadTest do
  use ExUnit.Case, async: true

  setup do
    # Wrong: bare start_link. Nothing stops this before the next test starts.
    {:ok, pid} = StartSupervisedBadAgent.start_link(name: __MODULE__)
    %{agent: pid}
  end

  test "agent starts with nil and stores a new value", %{agent: pid} do
    assert StartSupervisedBadAgent.get(pid) == nil
    StartSupervisedBadAgent.put(pid, 42)
    assert StartSupervisedBadAgent.get(pid) == 42
  end
end
