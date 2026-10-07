# EXPECTED: passes
# BAD PRACTICE: The code under test starts a session under an app-level
# DynamicSupervisor and nothing stops it. start_supervised never saw the child,
# so each test leaves one behind and every later test runs beside the leftovers,
# which can reach its global mocks and its shared sandbox.
Mix.install([])

defmodule StopIndirectBadApp.Sessions do
  # Stands in for a LiveView mount or a context function that opens a session.
  def open(id) do
    DynamicSupervisor.start_child(StopIndirectBadApp.SessionSupervisor, {Agent, fn -> id end})
  end
end

# The application's supervisor: started outside any test and unlinked, the way
# the app tree owns it.
{:ok, sup} =
  DynamicSupervisor.start_link(name: StopIndirectBadApp.SessionSupervisor, strategy: :one_for_one)

Process.unlink(sup)

ExUnit.start(autorun: true)

defmodule StopIndirectBadTest do
  use ExUnit.Case, async: false

  test "the first test opens a session" do
    assert {:ok, _pid} = StopIndirectBadApp.Sessions.open(1)
  end

  test "the second test opens a session" do
    assert {:ok, _pid} = StopIndirectBadApp.Sessions.open(2)

    # Whichever test runs second sees the first test's session still alive.
    # Nothing here stops either of them.
    assert DynamicSupervisor.count_children(StopIndirectBadApp.SessionSupervisor).active >= 1
  end
end
