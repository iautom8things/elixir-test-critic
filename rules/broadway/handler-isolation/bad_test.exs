# EXPECTED: passes
# BAD PRACTICE: Starting a full pipeline (simulated here) to test handler logic
# that could be tested by calling the functions directly.
# This is slow, must run async: false, requires setup/teardown overhead —
# all unnecessary for testing pure transformation functions.
Mix.install([])

ExUnit.start(autorun: true)

defmodule BwayHandlerBadTest.Message do
  defstruct [:data, :status, :acknowledger]

  def new(data) do
    %__MODULE__{data: data, status: :ok, acknowledger: :noop}
  end

  def put_data(msg, data), do: %{msg | data: data}
  def failed(msg, reason), do: %{msg | status: {:failed, reason}}
end

# Handler logic we want to test
defmodule BwayHandlerBadTest.Pipeline do
  alias BwayHandlerBadTest.Message

  def handle_message(_processor, %Message{data: data} = msg, _context) do
    if String.length(data) > 3 do
      Message.put_data(msg, String.upcase(data))
    else
      Message.failed(msg, "too short")
    end
  end
end

# BAD: Simulate a "full pipeline" with GenServer start/stop overhead
# just to call what is essentially a plain function
defmodule BwayHandlerBadTest.FullPipelineSimulation do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  def stop, do: GenServer.stop(__MODULE__)

  def process_via_pipeline(data) do
    GenServer.call(__MODULE__, {:process, data})
  end

  @impl true
  def init(_), do: {:ok, nil}

  @impl true
  def handle_call({:process, data}, _from, state) do
    msg = BwayHandlerBadTest.Message.new(data)
    # BAD: going through the pipeline infrastructure when we could call handle_message/3 directly
    result = BwayHandlerBadTest.Pipeline.handle_message(:default, msg, %{})
    {:reply, result, state}
  end
end

defmodule BwayHandlerBadTest do
  # BAD: async: false — only necessary because of the named GenServer
  use ExUnit.Case, async: false

  # BAD: setup/teardown overhead for every test — not needed for pure functions
  setup do
    {:ok, pid} = BwayHandlerBadTest.FullPipelineSimulation.start_link(nil)
    on_exit(fn ->
      if Process.alive?(pid) do
        try do
          BwayHandlerBadTest.FullPipelineSimulation.stop()
        catch
          :exit, _ -> :ok
        end
      end
    end)
    :ok
  end

  test "BAD: routes through GenServer to call what is a plain function" do
    # This works, but it's needlessly complex
    # The good version is just: Pipeline.handle_message(:default, msg, %{})
    result = BwayHandlerBadTest.FullPipelineSimulation.process_via_pipeline("hello world")

    assert result.status == :ok
    assert result.data == "HELLO WORLD"
  end

  test "BAD: additional GenServer overhead for another simple case" do
    result = BwayHandlerBadTest.FullPipelineSimulation.process_via_pipeline("hi")

    assert {:failed, "too short"} = result.status
  end

  test "demonstrates what the GOOD version looks like — no infrastructure needed" do
    # GOOD: just call the function directly — no GenServer, no start/stop, can be async: true
    msg = BwayHandlerBadTest.Message.new("hello world")
    result = BwayHandlerBadTest.Pipeline.handle_message(:default, msg, %{})

    assert result.status == :ok
    assert result.data == "HELLO WORLD"
  end
end
