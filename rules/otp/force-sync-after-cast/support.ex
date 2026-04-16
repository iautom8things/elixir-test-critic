# support.ex — shared GenServer for ETC-OTP-003 good and bad tests
# Usage: Code.require_file("support.ex", __DIR__)

defmodule OTP003.EventLog do
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, [], opts)

  # Async: fire and forget
  def log_event(pid, event), do: GenServer.cast(pid, {:log, event})

  # Sync: returns immediately after processing
  def flush(pid), do: GenServer.call(pid, :flush)
  def get_events(pid), do: GenServer.call(pid, :get_events)
  def clear(pid), do: GenServer.call(pid, :clear)

  @impl true
  def init(events), do: {:ok, events}

  @impl true
  def handle_cast({:log, event}, events), do: {:noreply, [event | events]}

  @impl true
  def handle_call(:flush, _from, events), do: {:reply, :ok, events}
  def handle_call(:get_events, _from, events), do: {:reply, Enum.reverse(events), events}
  def handle_call(:clear, _from, _events), do: {:reply, :ok, []}
end
