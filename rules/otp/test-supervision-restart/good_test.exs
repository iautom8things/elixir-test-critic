# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP005.Counter do
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, 0, opts)
  def increment(pid), do: GenServer.call(pid, :increment)
  def get(pid), do: GenServer.call(pid, :get)

  @impl true
  def init(count), do: {:ok, count}

  @impl true
  def handle_call(:increment, _from, count), do: {:reply, count + 1, count + 1}
  def handle_call(:get, _from, count), do: {:reply, count, count}
end

defmodule OTP005.SupervisionRestartGoodTest do
  use ExUnit.Case, async: true

  # Helper to retry a condition up to N times with a short sleep between attempts
  defp wait_until(fun, retries \\ 20) do
    if fun.() do
      :ok
    else
      if retries > 0 do
        Process.sleep(10)
        wait_until(fun, retries - 1)
      else
        flunk("Condition not met within timeout")
      end
    end
  end

  test "supervisor restarts worker after crash" do
    # Start a real supervisor with a real child spec
    name = :"counter_good_#{System.unique_integer([:positive])}"

    {:ok, _sup} =
      Supervisor.start_link(
        [{OTP005.Counter, [name: name]}],
        strategy: :one_for_one
      )

    original_pid = Process.whereis(name)
    assert is_pid(original_pid)

    # Crash the worker — the supervisor should restart it
    Process.exit(original_pid, :kill)

    # Wait for the supervisor to restart the child
    wait_until(fn ->
      new_pid = Process.whereis(name)
      new_pid != nil and new_pid != original_pid
    end)

    new_pid = Process.whereis(name)
    assert new_pid != original_pid
    # The restarted process starts fresh
    assert OTP005.Counter.get(new_pid) == 0
  end

  test "restarted worker has clean initial state" do
    name = :"counter_restart_#{System.unique_integer([:positive])}"

    {:ok, _sup} =
      Supervisor.start_link(
        [{OTP005.Counter, [name: name]}],
        strategy: :one_for_one
      )

    pid1 = Process.whereis(name)
    OTP005.Counter.increment(pid1)
    OTP005.Counter.increment(pid1)
    assert OTP005.Counter.get(pid1) == 2

    Process.exit(pid1, :kill)

    wait_until(fn ->
      p = Process.whereis(name)
      p != nil and p != pid1
    end)

    # New process should start from 0, not from 2
    pid2 = Process.whereis(name)
    assert OTP005.Counter.get(pid2) == 0
  end
end
