# EXPECTED: passes
# BAD PRACTICE: Process.sleep used to synchronize with a GenServer cast.
# The test passes because 100ms is enough on this machine. Under CI load or
# on slower hardware it would fail intermittently.
Mix.install([])

ExUnit.start(autorun: true)

defmodule NoProcessSleepBadCounter do
  use GenServer

  def start_link(initial), do: GenServer.start_link(__MODULE__, initial)
  def increment(pid), do: GenServer.cast(pid, :increment)
  def value(pid), do: GenServer.call(pid, :value)

  def init(n), do: {:ok, n}
  def handle_cast(:increment, n), do: {:noreply, n + 1}
  def handle_call(:value, _from, n), do: {:reply, n, n}
end

defmodule NoProcessSleepBadTest do
  use ExUnit.Case, async: true

  test "counter increments (with sleep — flaky under load)" do
    {:ok, pid} = NoProcessSleepBadCounter.start_link(0)
    NoProcessSleepBadCounter.increment(pid)
    # Wrong: guessing 100ms is enough. A GenServer.call(:value) would be deterministic.
    Process.sleep(100)
    assert NoProcessSleepBadCounter.value(pid) == 1
  end
end
