# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule DeadlineGood.Client do
  # One budget covers the whole exchange: initialize, initialized, call.
  def call(server, deadline_ms) do
    task =
      Task.async(fn ->
        for step <- [:initialize, :initialized, :call] do
          # Stands in for encoding, file reads and round trips.
          Process.sleep(10)
          server.(step)
        end
      end)

    case Task.yield(task, deadline_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      _ -> {:error, :timeout}
    end
  end
end

defmodule DeadlineGoodTest do
  use ExUnit.Case, async: true

  test "a deadline kills the in-flight call" do
    owner = self()

    # Block the first request, so nothing but the task's start sits inside the
    # budget, and give the budget a wide margin over a loaded runner's worst
    # case. The task runs the server, so its message lands before its exit.
    server = fn _any_step ->
      send(owner, {:blocked, self()})

      receive do
        :never -> :never
      end
    end

    assert {:error, :timeout} = DeadlineGood.Client.call(server, 1_000)
    assert_received {:blocked, pid}
    refute Process.alive?(pid)
  end
end
