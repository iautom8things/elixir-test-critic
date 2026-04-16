# EXPECTED: passes
# Demonstrates: testing observable behaviour (return value, side effect)
# rather than internal call interactions.
Mix.install([])

ExUnit.start(autorun: true)

defmodule MyApp.BehaviourGoodTest.Inventory do
  def reserve("sold_out_item", _qty), do: {:error, :out_of_stock}
  def reserve(_item, _qty), do: :ok
end

defmodule MyApp.BehaviourGoodTest.Orders do
  alias MyApp.BehaviourGoodTest.Inventory

  def place_order(%{item: item, qty: qty}) do
    case Inventory.reserve(item, qty) do
      :ok -> {:ok, %{status: :confirmed, item: item, qty: qty}}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule MyApp.BehaviourGoodTest do
  use ExUnit.Case, async: true

  alias MyApp.BehaviourGoodTest.Orders

  # GOOD: Asserts on the return value — the observable behaviour
  test "place_order returns a confirmed order for an available item" do
    result = Orders.place_order(%{item: "widget", qty: 2})

    assert {:ok, order} = result
    assert order.status == :confirmed
    assert order.item == "widget"
    assert order.qty == 2
  end

  # GOOD: Asserts on the error case — observable behaviour
  test "place_order returns out_of_stock error for unavailable item" do
    result = Orders.place_order(%{item: "sold_out_item", qty: 1})
    assert {:error, :out_of_stock} = result
  end

  # These tests survive any internal refactor to Orders or Inventory:
  # - Inline Inventory.reserve into Orders -> tests still pass
  # - Rename Inventory to StockManager -> tests still pass
  # - Add caching layer -> tests still pass
  # Only the observable outcome matters.
end
