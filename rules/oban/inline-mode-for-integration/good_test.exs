# EXPECTED: passes
# Demonstrates the CONCEPT of inline testing mode without requiring Oban/Postgres.
# In a real app: set `config :my_app, Oban, testing: :inline` in config/test.exs.
# Here we simulate inline mode: inserting a job immediately calls perform/1.
Mix.install([])

ExUnit.start(autorun: true)

defmodule InlineMode.ResultStore do
  use Agent
  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def record(item), do: Agent.update(__MODULE__, &[item | &1])
  def all, do: Agent.get(__MODULE__, & &1)
end

defmodule InlineMode.FulfillmentWorker do
  def perform(%{"order_id" => id}) do
    InlineMode.ResultStore.record(%{order_id: id, status: :fulfilled})
    :ok
  end
end

# Simulates Oban in :inline mode — insert/1 calls perform/1 synchronously
defmodule InlineMode.Oban do
  def insert(worker, args) do
    # In :inline mode, job executes immediately in the calling process
    result = worker.perform(args)
    {:ok, %{worker: worker, args: args, result: result}}
  end
end

defmodule InlineMode.Orders do
  def place_order(%{order_id: id}) do
    InlineMode.Oban.insert(InlineMode.FulfillmentWorker, %{"order_id" => id})
  end
end

defmodule InlineMode.GoodTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!({InlineMode.ResultStore, []})
    :ok
  end

  test "GOOD: inline mode — place_order triggers fulfillment synchronously, no drain needed" do
    # With inline mode, insert runs perform/1 immediately
    InlineMode.Orders.place_order(%{order_id: 42})

    # No Oban.drain_queue/1 needed — the job already ran
    results = InlineMode.ResultStore.all()
    assert Enum.any?(results, &(&1.order_id == 42 and &1.status == :fulfilled))
  end

  test "multiple orders each fulfil synchronously" do
    InlineMode.Orders.place_order(%{order_id: 1})
    InlineMode.Orders.place_order(%{order_id: 2})

    results = InlineMode.ResultStore.all()
    order_ids = Enum.map(results, & &1.order_id) |> Enum.sort()
    assert order_ids == [1, 2]
  end
end
