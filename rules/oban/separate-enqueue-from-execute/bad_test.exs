# EXPECTED: passes
# BAD PRACTICE: A single test that both schedules a job AND runs the worker,
# mixing two concerns. When this test fails, you can't tell if scheduling or
# execution broke. It's also harder to test edge cases for each layer independently.
Mix.install([])

ExUnit.start(autorun: true)

defmodule SeparateBad.JobStore do
  use Agent
  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def insert(worker, args), do: Agent.update(__MODULE__, &[%{worker: worker, args: args} | &1])
  def jobs, do: Agent.get(__MODULE__, & &1)
  def drain_and_run do
    jobs = Agent.get_and_update(__MODULE__, fn jobs -> {jobs, []} end)
    Enum.map(jobs, fn %{worker: w, args: a} -> w.perform(a) end)
  end
end

defmodule SeparateBad.ResultStore do
  use Agent
  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def record(item), do: Agent.update(__MODULE__, &[item | &1])
  def all, do: Agent.get(__MODULE__, & &1)
end

defmodule SeparateBad.Orders do
  def place_order(%{order_id: id}) do
    SeparateBad.JobStore.insert(SeparateBad.FulfillmentWorker, %{"order_id" => id})
    :ok
  end
end

defmodule SeparateBad.FulfillmentWorker do
  def perform(%{"order_id" => id}) do
    SeparateBad.ResultStore.record(%{order_id: id, status: :fulfilled})
    :ok
  end
end

defmodule SeparateBad.CombinedTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!({SeparateBad.JobStore, []})
    start_supervised!({SeparateBad.ResultStore, []})
    :ok
  end

  test "BAD: place_order triggers fulfillment — scheduling and execution in one test" do
    # Concern 1: scheduling
    SeparateBad.Orders.place_order(%{order_id: 42})

    # "Drain" the queue inline — couples test to queue mechanics
    SeparateBad.JobStore.drain_and_run()

    # Concern 2: execution side effect
    # If this fails, was it scheduling or execution? We don't know.
    results = SeparateBad.ResultStore.all()
    assert Enum.any?(results, &(&1.order_id == 42))
  end

  # Notice: there is no test for the worker's edge cases (e.g., unknown order)
  # and no test for whether the queue name is correct — both got lost in the combined test.
end
