# EXPECTED: passes
# Demonstrates the CONCEPT of test_message/3 — inject one message, get a ref,
# assert on the ack with the pinned ref.
# In real Broadway: Broadway.test_message(pid, data) returns a ref and triggers
# {:ack, ^ref, successful, failed} sent to the test process.
# Here we simulate that exact message-passing protocol without starting a pipeline.
Mix.install([])

ExUnit.start(autorun: true)

# Simulates what Broadway.DummyProducer + Broadway.test_message/3 do internally:
# accept a message, process it, send {:ack, ref, successful, failed} to the caller.
defmodule BwayTestMsgGoodTest.SimulatedPipeline do
  use GenServer

  def start_link(handler) do
    GenServer.start_link(__MODULE__, handler)
  end

  def stop(pid), do: GenServer.stop(pid)

  # Simulates Broadway.test_message/3: returns a ref, sends ack when done
  def test_message(pid, data) do
    ref = make_ref()
    caller = self()
    GenServer.cast(pid, {:process, ref, caller, data})
    ref
  end

  @impl true
  def init(handler), do: {:ok, %{handler: handler}}

  @impl true
  def handle_cast({:process, ref, caller, data}, %{handler: handler} = state) do
    msg = %{data: data, status: :ok}

    result = handler.(msg)

    {successful, failed} =
      case result.status do
        :ok -> {[result], []}
        {:failed, _} -> {[], [result]}
      end

    send(caller, {:ack, ref, successful, failed})
    {:noreply, state}
  end
end

defmodule BwayTestMsgGoodTest do
  use ExUnit.Case, async: true

  # Simulated handle_message logic
  defp handler(msg) do
    if String.starts_with?(msg.data, "valid") do
      %{msg | data: String.upcase(msg.data)}
    else
      %{msg | status: {:failed, "invalid data"}}
    end
  end

  setup do
    {:ok, pid} = BwayTestMsgGoodTest.SimulatedPipeline.start_link(&handler/1)
    on_exit(fn ->
      if Process.alive?(pid), do: BwayTestMsgGoodTest.SimulatedPipeline.stop(pid)
    end)
    {:ok, pid: pid}
  end

  test "test_message returns a ref and triggers ack for valid data", %{pid: pid} do
    # GOOD: capture the ref, pin it in assert_receive
    ref = BwayTestMsgGoodTest.SimulatedPipeline.test_message(pid, "valid-payload")

    assert_receive {:ack, ^ref, successful, failed}
    assert length(successful) == 1
    assert failed == []
  end

  test "ack contains the processed message data", %{pid: pid} do
    ref = BwayTestMsgGoodTest.SimulatedPipeline.test_message(pid, "valid-hello")

    assert_receive {:ack, ^ref, [msg], []}
    # The handler transformed the data
    assert msg.data == "VALID-HELLO"
  end

  test "failed message lands in the failed list", %{pid: pid} do
    ref = BwayTestMsgGoodTest.SimulatedPipeline.test_message(pid, "bad-data")

    assert_receive {:ack, ^ref, successful, failed}
    assert successful == []
    assert [msg] = failed
    assert {:failed, "invalid data"} = msg.status
  end

  test "multiple test_message calls each produce distinct acks", %{pid: pid} do
    ref1 = BwayTestMsgGoodTest.SimulatedPipeline.test_message(pid, "valid-one")
    ref2 = BwayTestMsgGoodTest.SimulatedPipeline.test_message(pid, "valid-two")

    # Each ref pins to its own ack — no interference
    assert_receive {:ack, ^ref1, [_], []}
    assert_receive {:ack, ^ref2, [_], []}
  end
end
