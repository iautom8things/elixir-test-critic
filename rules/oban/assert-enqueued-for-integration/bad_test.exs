# EXPECTED: passes
# BAD PRACTICE: Verifying enqueueing by inspecting the return value of insert/1
# instead of querying the actual job store. This couples tests to implementation
# details and doesn't verify the queue or other scheduling properties.
Mix.install([])

ExUnit.start(autorun: true)

defmodule MyApp.BadJobStore do
  use Agent

  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)

  def insert(worker, args, opts \\ []) do
    job = %{worker: worker, args: args, queue: Keyword.get(opts, :queue, :default)}
    Agent.update(__MODULE__, fn jobs -> [job | jobs] end)
    {:ok, job}
  end
end

defmodule MyApp.BadOrders do
  def place_order(%{item: item, qty: qty}) do
    MyApp.BadJobStore.insert(MyApp.BadFulfillmentWorker, %{item: item, qty: qty},
      queue: :fulfillment
    )
  end
end

defmodule MyApp.AssertEnqueuedBadTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!({MyApp.BadJobStore, []})
    :ok
  end

  test "places order — inspects return value instead of asserting on the store" do
    # BAD: pattern-matching the return value of place_order/1
    # This only checks what insert/1 returned, not what's actually in the job store.
    # Doesn't verify queue, doesn't verify the job persisted, couples to return shape.
    {:ok, job} = MyApp.BadOrders.place_order(%{item: "widget", qty: 3})

    # Fragile assertions on return value — the worker could still be wrong in the DB
    assert job.worker == MyApp.BadFulfillmentWorker
    assert job.args[:item] == "widget"
    # Notice: we never verified the queue is :fulfillment
    # Notice: we never verified the job is actually findable in the store
  end
end
