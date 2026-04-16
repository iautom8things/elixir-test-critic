# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

# The pure logic module — no process, no GenServer
defmodule OTP001.CounterLogic do
  def increment(count), do: count + 1
  def decrement(count), do: max(0, count - 1)
  def reset(_count), do: 0
  def apply_delta(count, delta), do: max(0, count + delta)
end

# The thin GenServer wrapper (not under test here)
defmodule OTP001.Counter do
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, 0, opts)
  def increment(pid), do: GenServer.cast(pid, :increment)
  def get(pid), do: GenServer.call(pid, :get)

  @impl true
  def init(count), do: {:ok, count}

  @impl true
  def handle_cast(:increment, count), do: {:noreply, OTP001.CounterLogic.increment(count)}

  @impl true
  def handle_call(:get, _from, count), do: {:reply, count, count}
end

defmodule OTP001.CounterLogicTest do
  use ExUnit.Case, async: true

  alias OTP001.CounterLogic

  test "increment adds 1" do
    assert CounterLogic.increment(0) == 1
    assert CounterLogic.increment(5) == 6
  end

  test "decrement subtracts 1" do
    assert CounterLogic.decrement(5) == 4
  end

  test "decrement floors at zero" do
    assert CounterLogic.decrement(0) == 0
  end

  test "reset returns zero regardless of input" do
    assert CounterLogic.reset(42) == 0
    assert CounterLogic.reset(0) == 0
  end

  test "apply_delta handles positive and negative deltas" do
    assert CounterLogic.apply_delta(10, 5) == 15
    assert CounterLogic.apply_delta(10, -3) == 7
    assert CounterLogic.apply_delta(2, -10) == 0
  end

  test "composable: two increments from zero" do
    result = 0 |> CounterLogic.increment() |> CounterLogic.increment()
    assert result == 2
  end
end
