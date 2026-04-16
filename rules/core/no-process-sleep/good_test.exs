# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule NoProcessSleepCounter do
  use GenServer

  def start_link(initial), do: GenServer.start_link(__MODULE__, initial)
  def increment(pid), do: GenServer.cast(pid, :increment)
  def value(pid), do: GenServer.call(pid, :value)

  def init(n), do: {:ok, n}
  def handle_cast(:increment, n), do: {:noreply, n + 1}
  def handle_call(:value, _from, n), do: {:reply, n, n}
end

defmodule NoProcessSleepGoodTest do
  use ExUnit.Case, async: true

  test "counter increments without sleeping" do
    {:ok, pid} = NoProcessSleepCounter.start_link(0)
    NoProcessSleepCounter.increment(pid)
    # GenServer.call forces synchronization — the cast is processed before the call returns
    assert NoProcessSleepCounter.value(pid) == 1
  end

  test "worker sends completion message" do
    test_pid = self()
    spawn(fn -> send(test_pid, {:done, 42}) end)
    assert_receive {:done, result}, 500
    assert result == 42
  end
end
