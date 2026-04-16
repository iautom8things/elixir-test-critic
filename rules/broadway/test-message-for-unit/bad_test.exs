# EXPECTED: flaky
# BAD PRACTICE: Testing pipeline message handling without pinning the ref,
# or using Process.sleep instead of assert_receive.
# These tests demonstrate fragile patterns — they may pass coincidentally but
# can produce false positives or race conditions in real pipelines. The
# EXPECTED marker is "flaky" because that is literally the point: under CI
# load the race condition manifests and the test fails, exactly as the rule
# warns.
Mix.install([])

ExUnit.start(autorun: true)

defmodule BwayTestMsgBadTest.SimulatedPipeline do
  use GenServer

  def start_link(handler) do
    GenServer.start_link(__MODULE__, handler)
  end

  def stop(pid), do: GenServer.stop(pid)

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

defmodule BwayTestMsgBadTest do
  use ExUnit.Case, async: true

  defp handler(msg), do: msg

  setup do
    {:ok, pid} = BwayTestMsgBadTest.SimulatedPipeline.start_link(&handler/1)
    on_exit(fn ->
      if Process.alive?(pid), do: BwayTestMsgBadTest.SimulatedPipeline.stop(pid)
    end)
    {:ok, pid: pid}
  end

  test "BAD: discards the ref — can match any ack in the mailbox", %{pid: pid} do
    # BAD: ref is thrown away — this matches the first ack regardless of which message it's for
    _ref = BwayTestMsgBadTest.SimulatedPipeline.test_message(pid, "hello")

    # Without ^ref pin, this could match an ack from a completely different message
    assert_receive {:ack, _ref, _successful, _failed}
  end

  test "BAD: sleeping to wait — timing-dependent and fragile", %{pid: pid} do
    BwayTestMsgBadTest.SimulatedPipeline.test_message(pid, "hello")

    # BAD: arbitrary sleep — may be too short under load, wastes time otherwise
    # In a real pipeline this would be Process.sleep(500) or similar
    Process.sleep(10)

    # assert_received has NO timeout — races with pipeline completion
    assert_received {:ack, _ref, _successful, _failed}
  end

  test "demonstrates why ref pinning matters: two messages, wrong match", %{pid: pid} do
    ref1 = BwayTestMsgBadTest.SimulatedPipeline.test_message(pid, "first")
    _ref2 = BwayTestMsgBadTest.SimulatedPipeline.test_message(pid, "second")

    # BAD: matching ref1 but not checking that it IS ref1
    # In a concurrent system, the second ack could arrive first
    assert_receive {:ack, ^ref1, [_], []}
    # Both acks will be in mailbox — but we didn't verify the second one
    assert_received {:ack, _, [_], []}
  end
end
