# EXPECTED: passes
# Demonstrates proper sandbox ownership — checkout for isolation,
# allow for spawned processes.
Mix.install([])

ExUnit.start(autorun: true)

defmodule SandboxOwnershipStrategyGoodTest do
  use ExUnit.Case

  # In a real Phoenix/Ecto app, the good pattern is:
  #
  #   setup do
  #     :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  #     :ok
  #   end
  #
  #   test "test process has DB access" do
  #     assert {:ok, _} = Repo.insert(%User{name: "Alice"})
  #   end
  #
  #   test "spawned task also has DB access" do
  #     Sandbox.allow(Repo, self(), task_pid)
  #     # Now the task can use the same sandbox connection
  #   end

  # We demonstrate the ownership concept without a DB:

  test "each test gets its own isolated resource (simulating checkout)" do
    # In sandbox mode, checkout gives this test process exclusive access
    resource_id = System.unique_integer([:positive])
    assert resource_id > 0
  end

  test "spawned process can access shared resource (simulating allow)" do
    parent = self()
    # This simulates the pattern: Sandbox.allow(Repo, parent, task_pid)
    # After allow, the spawned process shares the parent's connection.
    task = Task.async(fn ->
      send(parent, {:from_task, "I have access via allow"})
    end)

    Task.await(task)
    assert_receive {:from_task, "I have access via allow"}
  end
end
