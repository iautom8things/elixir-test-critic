# EXPECTED: passes
# BAD PRACTICE: The GenServer uses a hardcoded timer interval read from a module
# attribute. To make tests fast, the interval is set to a very small value, but
# this still requires real sleeping and is inherently flaky. The better approach
# is to inject the interval as an option so tests can disable the timer entirely
# and drive ticks manually.
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP006Bad.Heartbeat do
  use GenServer

  # Hardcoded interval — must be very small in tests or we wait forever.
  # In production this would be 60_000 ms but we cheat for tests.
  @tick_interval 30

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, [], opts)
  def tick_count(pid), do: GenServer.call(pid, :tick_count)

  @impl true
  def init(_) do
    # Timer is unconditionally started — tests can't opt out of real time
    Process.send_after(self(), :tick, @tick_interval)
    {:ok, %{count: 0}}
  end

  @impl true
  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, @tick_interval)
    {:noreply, %{state | count: state.count + 1}}
  end

  @impl true
  def handle_call(:tick_count, _from, state), do: {:reply, state.count, state}
end

defmodule OTP006Bad.ControllableTimeBadTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = GenServer.start_link(OTP006Bad.Heartbeat, [])
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{hb: pid}
  end

  test "heartbeat ticks after waiting (fragile sleep-based test)", %{hb: hb} do
    # Must sleep to let the real timer fire — brittle under load
    # If the machine is slow, this might not be enough time
    Process.sleep(50)
    count = OTP006Bad.Heartbeat.tick_count(hb)
    # Could be 1 or more depending on timing — inherently non-deterministic
    assert count >= 1
  end
end
