# EXPECTED: passes
# BAD PRACTICE: Testing internal call interactions instead of observable behaviour.
# This test verifies that Orders called Inventory — not that the order was placed.
# It will break if Inventory is renamed, inlined, or the call order changes.
Mix.install([])

ExUnit.start(autorun: true)

# A simple call tracker to simulate Mox interaction verification
defmodule MyApp.BehaviourBadTest.CallTracker do
  use Agent
  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def record(call), do: Agent.update(__MODULE__, &[call | &1])
  def calls, do: Agent.get(__MODULE__, & &1)
  def reset, do: Agent.update(__MODULE__, fn _ -> [] end)
end

defmodule MyApp.BehaviourBadTest.Inventory do
  def reserve(item, qty) do
    MyApp.BehaviourBadTest.CallTracker.record({:reserve, item, qty})
    :ok
  end
end

defmodule MyApp.BehaviourBadTest.Orders do
  alias MyApp.BehaviourBadTest.Inventory

  def place_order(%{item: item, qty: qty}) do
    case Inventory.reserve(item, qty) do
      :ok -> {:ok, %{status: :confirmed, item: item, qty: qty}}
      error -> error
    end
  end
end

defmodule MyApp.BehaviourBadTest do
  use ExUnit.Case, async: false

  alias MyApp.BehaviourBadTest.Orders
  alias MyApp.BehaviourBadTest.CallTracker

  setup do
    start_supervised!({CallTracker, []})
    :ok
  end

  # BAD: Testing THAT Inventory.reserve was called, not WHAT the order outcome was.
  # If we inline reserve into Orders, this test breaks — even though orders still work.
  test "BAD: place_order calls Inventory.reserve with correct args" do
    Orders.place_order(%{item: "widget", qty: 2})

    # Asserting on internal interaction — fragile!
    calls = CallTracker.calls()
    assert {:reserve, "widget", 2} in calls

    # Notice: we never checked the return value of place_order.
    # We don't know if the order was confirmed or not — only that a call was made.
  end
end
