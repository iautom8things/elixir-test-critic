# EXPECTED: passes
# BAD PRACTICE: Ack assertions without ref pinning or without checking both lists.
# These patterns can produce false positives — a test passes even when the wrong
# message was acked, or when a message was accidentally failed.
Mix.install([])

ExUnit.start(autorun: true)

defmodule BwayAckBadTest.SimulatedPipeline do
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
        {:failed, reason} -> {[], [%{result | status: {:failed, reason}}]}
      end
    send(caller, {:ack, ref, successful, failed})
    {:noreply, state}
  end
end

defmodule BwayAckBadTest do
  use ExUnit.Case, async: true

  defp simple_handler(msg), do: msg

  setup do
    {:ok, pid} = BwayAckBadTest.SimulatedPipeline.start_link(&simple_handler/1)
    on_exit(fn ->
      if Process.alive?(pid), do: BwayAckBadTest.SimulatedPipeline.stop(pid)
    end)
    {:ok, pid: pid}
  end

  test "BAD: no ref pinning — matches the first ack in the mailbox", %{pid: pid} do
    _ref = BwayAckBadTest.SimulatedPipeline.test_message(pid, "message-1")
    _ref2 = BwayAckBadTest.SimulatedPipeline.test_message(pid, "message-2")

    # BAD: _ref matches anything — could be ack for message-2 not message-1
    # In concurrent systems (real Broadway) ordering is not guaranteed
    assert_receive {:ack, _ref, _successful, _failed}
  end

  test "BAD: ignoring the failed list — hidden failures go undetected", %{pid: pid} do
    ref = BwayAckBadTest.SimulatedPipeline.test_message(pid, "some-message")

    # BAD: using _ for failed — if the message was accidentally failed, this still passes
    assert_receive {:ack, ^ref, [_msg], _}
    # We never checked that failed is empty — a bug in the handler could fail the message
    # and this test would still pass
  end

  test "BAD: ignoring the successful list — misses unexpected successes", %{pid: pid} do
    ref = BwayAckBadTest.SimulatedPipeline.test_message(pid, "some-message")

    # BAD: using _ for successful — we don't know if the right data was processed
    assert_receive {:ack, ^ref, _, _failed}
  end

  test "demonstrates what proper assertions catch" do
    # To illustrate: with proper assertions, a mismatch between expected success
    # and actual failure would be caught
    successful = [%{data: "processed", status: :ok}]
    failed = []

    # GOOD form (in a real test, would use assert_receive with ^ref):
    assert length(successful) == 1
    assert failed == []
  end
end
