# EXPECTED: passes
# Demonstrates separation of scheduling vs execution concerns.
# Two independent test modules: one for "was it enqueued?", one for "did it work?".
Mix.install([])

ExUnit.start(autorun: true)

# Shared state to simulate a job store and a results store
defmodule SeparateEnqueue.JobStore do
  use Agent
  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def insert(worker, args), do: Agent.update(__MODULE__, &[%{worker: worker, args: args} | &1])
  def jobs, do: Agent.get(__MODULE__, & &1)
end

defmodule SeparateEnqueue.ResultStore do
  use Agent
  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def record(item), do: Agent.update(__MODULE__, &[item | &1])
  def all, do: Agent.get(__MODULE__, & &1)
end

# Business logic — only responsible for scheduling
defmodule SeparateEnqueue.Orders do
  def place_order(%{order_id: id}) do
    SeparateEnqueue.JobStore.insert(SeparateEnqueue.FulfillmentWorker, %{"order_id" => id})
    :ok
  end
end

# Worker — only responsible for execution
defmodule SeparateEnqueue.FulfillmentWorker do
  def perform(%{"order_id" => 0}), do: {:discard, "unknown order"}

  def perform(%{"order_id" => id}) do
    SeparateEnqueue.ResultStore.record(%{order_id: id, status: :fulfilled})
    :ok
  end
end

# GOOD: Test 1 — only tests scheduling
defmodule SeparateEnqueue.SchedulingTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!({SeparateEnqueue.JobStore, []})
    :ok
  end

  test "place_order/1 enqueues a FulfillmentWorker job with order_id" do
    SeparateEnqueue.Orders.place_order(%{order_id: 42})

    jobs = SeparateEnqueue.JobStore.jobs()
    assert Enum.any?(jobs, &(&1.worker == SeparateEnqueue.FulfillmentWorker and &1.args["order_id"] == 42))
  end
end

# GOOD: Test 2 — only tests worker execution
defmodule SeparateEnqueue.WorkerTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!({SeparateEnqueue.ResultStore, []})
    :ok
  end

  test "perform/1 records fulfillment for valid order" do
    assert :ok = SeparateEnqueue.FulfillmentWorker.perform(%{"order_id" => 42})
    results = SeparateEnqueue.ResultStore.all()
    assert Enum.any?(results, &(&1.order_id == 42 and &1.status == :fulfilled))
  end

  test "perform/1 discards job for unknown order" do
    assert {:discard, "unknown order"} =
             SeparateEnqueue.FulfillmentWorker.perform(%{"order_id" => 0})
  end
end
