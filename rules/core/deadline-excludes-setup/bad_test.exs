# EXPECTED: passes
# BAD PRACTICE: The stub blocks only the client's last request, so its two setup
# requests share the 100 ms budget. Here they take about 20 ms and the test
# passes; on a loaded CI runner they can take the whole budget, the deadline
# fires before the blocking request is sent, and assert_received fails.
Mix.install([])

ExUnit.start(autorun: true)

defmodule DeadlineBad.Client do
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

defmodule DeadlineBadTest do
  use ExUnit.Case, async: true

  test "a deadline kills the in-flight call" do
    owner = self()

    server = fn
      :call ->
        send(owner, {:blocked, self()})

        receive do
          :never -> :never
        end

      _setup_step ->
        :ok
    end

    assert {:error, :timeout} = DeadlineBad.Client.call(server, 100)
    assert_received {:blocked, pid}
    refute Process.alive?(pid)
  end
end
