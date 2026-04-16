# EXPECTED: passes
# BAD PRACTICE: Spawning a process that accesses the database without
# Sandbox.allow. In a real Ecto test this raises DBConnection.OwnershipError.
# Here we demonstrate the concept without actually hitting the error.
Mix.install([])

ExUnit.start(autorun: true)

defmodule SandboxOwnershipStrategyBadTest do
  use ExUnit.Case

  # In real code, this is the bad pattern:
  #
  #   setup do
  #     :ok = Sandbox.checkout(Repo)
  #     :ok
  #   end
  #
  #   test "worker queries db" do
  #     {:ok, worker} = start_supervised(MyWorker)
  #     # Missing: Sandbox.allow(Repo, self(), worker)
  #     MyWorker.do_db_work(worker)   # => DBConnection.OwnershipError
  #   end
  #
  # The fix: call Sandbox.allow(Repo, self(), worker_pid) before
  # the spawned process touches the database.

  test "demonstrates the concept — spawned process without shared access" do
    parent = self()

    # Simulate a spawned process that tries to access a "resource"
    # without being granted access. In real code, this would be the DB.
    task = Task.async(fn ->
      # Without Sandbox.allow, the spawned process can't reach
      # the test's DB connection. We simulate with a simple check.
      has_access = false
      send(parent, {:access_result, has_access})
    end)

    Task.await(task)
    assert_receive {:access_result, false}
  end
end
