# EXPECTED: passes
# Demonstrates GOOD practice: asserting on {:ack, ^ref, successful, failed}
# with proper ref pinning and checking BOTH lists.
# Simulates Broadway's acknowledgment protocol without a real pipeline.
Mix.install([])

ExUnit.start(autorun: true)

defmodule BwayAckGoodTest.SimulatedPipeline do
  use GenServer

  def start_link(handler) do
    GenServer.start_link(__MODULE__, handler)
  end

  def stop(pid), do: GenServer.stop(pid)

  def test_message(pid, data, opts \\ []) do
    ref = make_ref()
    caller = self()
    metadata = Keyword.get(opts, :metadata, %{})
    GenServer.cast(pid, {:process, ref, caller, data, metadata})
    ref
  end

  @impl true
  def init(handler), do: {:ok, %{handler: handler}}

  @impl true
  def handle_cast({:process, ref, caller, data, metadata}, %{handler: handler} = state) do
    msg = %{data: data, metadata: metadata, status: :ok}
    result = handler.(msg)
    {successful, failed} =
      case result.status do
        :ok -> {[result], []}
        {:failed, reason} -> {[], [%{result | status: {:failed, reason}}]}
      end
    send(caller, {:ack, ref, successful, failed})
    {:noreply, state}
  end
end

defmodule BwayAckGoodTest do
  use ExUnit.Case, async: true

  # Handler that fails messages with "bad" in the data
  defp strict_handler(msg) do
    if String.contains?(msg.data, "bad") do
      %{msg | status: {:failed, "rejected: contains 'bad'"}}
    else
      %{msg | data: String.trim(msg.data)}
    end
  end

  setup do
    {:ok, pid} = BwayAckGoodTest.SimulatedPipeline.start_link(&strict_handler/1)
    on_exit(fn ->
      if Process.alive?(pid), do: BwayAckGoodTest.SimulatedPipeline.stop(pid)
    end)
    {:ok, pid: pid}
  end

  test "GOOD: pin ref and assert successful list has one item, failed is empty", %{pid: pid} do
    ref = BwayAckGoodTest.SimulatedPipeline.test_message(pid, "  hello  ")

    # Pin ^ref — won't accidentally match a different message's ack
    assert_receive {:ack, ^ref, successful, failed}
    assert [msg] = successful
    assert failed == []
    # Verify the handler transformed the data
    assert msg.data == "hello"
  end

  test "GOOD: assert failed list for expected failures", %{pid: pid} do
    ref = BwayAckGoodTest.SimulatedPipeline.test_message(pid, "bad-payload")

    assert_receive {:ack, ^ref, successful, failed}
    assert successful == []
    assert [msg] = failed
    assert {:failed, reason} = msg.status
    assert reason =~ "rejected"
  end

  test "GOOD: multiple messages, each ack matched to its own ref", %{pid: pid} do
    ref1 = BwayAckGoodTest.SimulatedPipeline.test_message(pid, "good-one")
    ref2 = BwayAckGoodTest.SimulatedPipeline.test_message(pid, "bad-two")
    ref3 = BwayAckGoodTest.SimulatedPipeline.test_message(pid, "good-three")

    assert_receive {:ack, ^ref1, [_], []}
    assert_receive {:ack, ^ref2, [], [_]}
    assert_receive {:ack, ^ref3, [_], []}
  end

  test "GOOD: check both lists are always present (not just happy path)", %{pid: pid} do
    ref = BwayAckGoodTest.SimulatedPipeline.test_message(pid, "clean")

    assert_receive {:ack, ^ref, successful, failed}
    # Explicitly assert BOTH lists — don't just match the one you expect
    assert length(successful) == 1
    assert length(failed) == 0
  end
end
