# EXPECTED: passes
# Demonstrates the CONCEPT of assert_enqueued/1 without requiring Oban/Postgres.
# In a real app: use Oban.Testing's assert_enqueued/1 to query the oban_jobs table.
# This test shows a clean in-memory job registry that mimics the pattern.
Mix.install([])

ExUnit.start(autorun: true)

# Simplified job store — simulates what Oban's database insertion does
defmodule MyApp.JobStore do
  use Agent

  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)

  def insert(worker, args, opts \\ []) do
    job = %{worker: worker, args: args, queue: Keyword.get(opts, :queue, :default)}
    Agent.update(__MODULE__, fn jobs -> [job | jobs] end)
    {:ok, job}
  end

  def all, do: Agent.get(__MODULE__, & &1)

  def reset, do: Agent.update(__MODULE__, fn _ -> [] end)
end

# Simulates assert_enqueued — checks the store for a matching job
defmodule MyApp.JobAssertions do
  import ExUnit.Assertions

  def assert_enqueued(opts) do
    jobs = MyApp.JobStore.all()
    worker = Keyword.get(opts, :worker)
    args = Keyword.get(opts, :args)
    queue = Keyword.get(opts, :queue)

    match =
      Enum.any?(jobs, fn job ->
        (is_nil(worker) or job.worker == worker) and
          (is_nil(args) or job.args == args) and
          (is_nil(queue) or job.queue == queue)
      end)

    assert match,
           "Expected a job to be enqueued matching #{inspect(opts)}, got: #{inspect(jobs)}"
  end

  def refute_enqueued(opts) do
    jobs = MyApp.JobStore.all()
    worker = Keyword.get(opts, :worker)

    match = Enum.any?(jobs, fn job -> is_nil(worker) or job.worker == worker end)

    refute match,
           "Expected no job enqueued for #{inspect(worker)}, but found one"
  end
end

# Business logic that schedules jobs
defmodule MyApp.Orders do
  def place_order(%{item: item, qty: qty}) when qty > 0 do
    MyApp.JobStore.insert(MyApp.FulfillmentWorker, %{item: item, qty: qty},
      queue: :fulfillment
    )
  end

  def place_order(%{item: "discontinued"}), do: {:error, :out_of_stock}
  def place_order(_), do: {:error, :invalid}
end

defmodule MyApp.AssertEnqueuedGoodTest do
  use ExUnit.Case, async: false
  import MyApp.JobAssertions

  setup do
    start_supervised!({MyApp.JobStore, []})
    :ok
  end

  test "places order and enqueues fulfillment job with correct args and queue" do
    MyApp.Orders.place_order(%{item: "widget", qty: 3})

    # GOOD: assert on worker, args, and queue — all three verified
    assert_enqueued(
      worker: MyApp.FulfillmentWorker,
      args: %{item: "widget", qty: 3},
      queue: :fulfillment
    )
  end

  test "out-of-stock item does not enqueue a fulfillment job" do
    MyApp.Orders.place_order(%{item: "discontinued"})
    refute_enqueued(worker: MyApp.FulfillmentWorker)
  end
end
