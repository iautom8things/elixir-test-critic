# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP006.Heartbeat do
  use GenServer

  # interval: 0 means "no automatic ticking" — tests drive ticks manually
  def start_link(opts \\ []) do
    {interval, genserver_opts} = Keyword.pop(opts, :interval, 5_000)
    GenServer.start_link(__MODULE__, interval, genserver_opts)
  end

  def tick_count(pid), do: GenServer.call(pid, :tick_count)

  @impl true
  def init(interval) do
    if interval > 0, do: Process.send_after(self(), :tick, interval)
    {:ok, %{count: 0, interval: interval}}
  end

  @impl true
  def handle_info(:tick, %{interval: interval} = state) do
    if interval > 0, do: Process.send_after(self(), :tick, interval)
    {:noreply, %{state | count: state.count + 1}}
  end

  @impl true
  def handle_call(:tick_count, _from, state), do: {:reply, state.count, state}
end

defmodule OTP006.ControllableTimeGoodTest do
  use ExUnit.Case, async: true

  setup do
    # interval: 0 disables the automatic timer — tests send ticks manually
    {:ok, pid} = GenServer.start_link(OTP006.Heartbeat, 0)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{hb: pid}
  end

  test "starts with zero ticks", %{hb: hb} do
    assert OTP006.Heartbeat.tick_count(hb) == 0
  end

  test "each manual tick increments the count", %{hb: hb} do
    send(hb, :tick)
    # Force sync: tick_count/1 is a call, processes mailbox first
    assert OTP006.Heartbeat.tick_count(hb) == 1
  end

  test "three manual ticks produce count of 3", %{hb: hb} do
    send(hb, :tick)
    send(hb, :tick)
    send(hb, :tick)
    assert OTP006.Heartbeat.tick_count(hb) == 3
  end

  test "no automatic ticking occurs without an interval", %{hb: hb} do
    # If the timer fired, the count would be non-zero by the time we check
    # Since interval: 0 was set, no timer is running
    Process.sleep(20)
    assert OTP006.Heartbeat.tick_count(hb) == 0
  end
end
