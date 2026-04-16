# EXPECTED: passes
# BAD PRACTICE: All logic assertions route through the GenServer process.
# This makes tests slower, harder to debug, and couples business logic
# to process infrastructure. A cast requires a sleep or sync hack to
# observe results. Logic that could be tested purely is buried in process calls.
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP001Bad.CounterServer do
  use GenServer

  # All the logic lives inside the GenServer — no separate pure module
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, 0, opts)
  def increment(pid), do: GenServer.cast(pid, :increment)
  def decrement(pid), do: GenServer.cast(pid, :decrement)
  def get(pid), do: GenServer.call(pid, :get)

  @impl true
  def init(count), do: {:ok, count}

  @impl true
  def handle_cast(:increment, count), do: {:noreply, count + 1}
  def handle_cast(:decrement, count), do: {:noreply, max(0, count - 1)}

  @impl true
  def handle_call(:get, _from, count), do: {:reply, count, count}
end

defmodule OTP001Bad.CounterTest do
  use ExUnit.Case, async: true

  # Every logic test requires spinning up a process
  setup do
    {:ok, pid} = GenServer.start_link(OTP001Bad.CounterServer, 0)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{pid: pid}
  end

  test "increment adds 1", %{pid: pid} do
    # Must go through process messaging to test a simple addition
    OTP001Bad.CounterServer.increment(pid)
    # Force sync via a call to avoid needing Process.sleep
    assert OTP001Bad.CounterServer.get(pid) == 1
  end

  test "decrement subtracts 1", %{pid: pid} do
    OTP001Bad.CounterServer.increment(pid)
    OTP001Bad.CounterServer.increment(pid)
    OTP001Bad.CounterServer.decrement(pid)
    assert OTP001Bad.CounterServer.get(pid) == 1
  end

  test "decrement floors at zero", %{pid: pid} do
    # Testing a pure guard clause requires a running process
    OTP001Bad.CounterServer.decrement(pid)
    assert OTP001Bad.CounterServer.get(pid) == 0
  end
end
