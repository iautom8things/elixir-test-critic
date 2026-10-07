# EXPECTED: passes
Mix.install([])

defmodule StopIndirectGoodApp.Sessions do
  # Stands in for a LiveView mount or a context function that opens a session.
  def open(id) do
    DynamicSupervisor.start_child(StopIndirectGoodApp.SessionSupervisor, {Agent, fn -> id end})
  end
end

defmodule StopIndirectGoodApp.TestProcesses do
  # Lives in test/support and is called from the case template, so no test has
  # to remember it. Exact only in sync tests: ExUnit runs them one at a time,
  # after every async module, so every child here came from this test or an
  # earlier one.
  def sweep! do
    for {_id, pid, _type, _modules} <-
          DynamicSupervisor.which_children(StopIndirectGoodApp.SessionSupervisor),
        is_pid(pid),
        do: DynamicSupervisor.terminate_child(StopIndirectGoodApp.SessionSupervisor, pid)

    :ok
  end
end

{:ok, sup} =
  DynamicSupervisor.start_link(name: StopIndirectGoodApp.SessionSupervisor, strategy: :one_for_one)

Process.unlink(sup)

ExUnit.start(autorun: true)

defmodule StopIndirectGoodTest do
  use ExUnit.Case, async: false

  # In a real suite this sits in DataCase.setup_sandbox/1: once before the
  # sandbox owner starts, and from an on_exit registered after the owner's, so
  # it runs while the sandbox is still open.
  setup do
    StopIndirectGoodApp.TestProcesses.sweep!()
    on_exit(&StopIndirectGoodApp.TestProcesses.sweep!/0)
  end

  test "opening a session leaves exactly one child, its own" do
    assert {:ok, pid} = StopIndirectGoodApp.Sessions.open(1)

    assert [{_id, ^pid, _type, _modules}] =
             DynamicSupervisor.which_children(StopIndirectGoodApp.SessionSupervisor)
  end

  test "the next test starts from an empty supervisor" do
    assert DynamicSupervisor.count_children(StopIndirectGoodApp.SessionSupervisor).active == 0
    assert {:ok, _pid} = StopIndirectGoodApp.Sessions.open(2)
  end
end
