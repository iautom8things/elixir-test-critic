# EXPECTED: passes
# BAD PRACTICE: Using Process.sleep/1 or manual drain to synchronise with job execution.
# These approaches are timing-dependent, slow, and fragile on CI.
Mix.install([])

ExUnit.start(autorun: true)

defmodule InlineModeBad.ResultStore do
  use Agent
  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def record(item), do: Agent.update(__MODULE__, &[item | &1])
  def all, do: Agent.get(__MODULE__, & &1)
end

defmodule InlineModeBad.FulfillmentWorker do
  def perform(%{"order_id" => id}) do
    InlineModeBad.ResultStore.record(%{order_id: id, status: :fulfilled})
    :ok
  end
end

# Simulates Oban in :manual mode — jobs are queued but NOT run automatically
defmodule InlineModeBad.JobQueue do
  use Agent
  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)

  def insert(worker, args) do
    Agent.update(__MODULE__, &[%{worker: worker, args: args} | &1])
    {:ok, %{worker: worker, args: args}}
  end

  def drain do
    jobs = Agent.get_and_update(__MODULE__, fn jobs -> {jobs, []} end)
    Enum.each(jobs, fn %{worker: w, args: a} -> w.perform(a) end)
  end
end

defmodule InlineModeBad.Orders do
  def place_order(%{order_id: id}) do
    InlineModeBad.JobQueue.insert(InlineModeBad.FulfillmentWorker, %{"order_id" => id})
  end
end

defmodule InlineModeBad.BadTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!({InlineModeBad.ResultStore, []})
    start_supervised!({InlineModeBad.JobQueue, []})
    :ok
  end

  test "BAD: must manually drain queue — fragile coupling to queue internals" do
    InlineModeBad.Orders.place_order(%{order_id: 42})

    # BAD: caller must know which queue to drain and when
    # In real Oban: Oban.drain_queue(queue: :fulfillment)
    InlineModeBad.JobQueue.drain()

    results = InlineModeBad.ResultStore.all()
    assert Enum.any?(results, &(&1.order_id == 42))
  end

  test "BAD: without drain, the job never runs — test would fail" do
    InlineModeBad.Orders.place_order(%{order_id: 99})

    # Forgot to drain! In real apps this might be a flaky Process.sleep instead
    # results = InlineModeBad.ResultStore.all()
    # assert Enum.any?(results, &(&1.order_id == 99))  # would fail!

    # Draining after the fact — shows the problem
    InlineModeBad.JobQueue.drain()
    results = InlineModeBad.ResultStore.all()
    assert Enum.any?(results, &(&1.order_id == 99))
  end
end
