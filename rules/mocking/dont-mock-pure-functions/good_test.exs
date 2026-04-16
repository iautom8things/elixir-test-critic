# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

# Pure price calculation module — no I/O, no side effects
defmodule MOCK009.PriceCalculator do
  def apply_discount(price, 0), do: price
  def apply_discount(price, discount_pct) when discount_pct > 0 and discount_pct < 100 do
    discount = price * discount_pct / 100
    Float.round(price - discount, 2)
  end

  def apply_tax(price, tax_rate) do
    tax = price * tax_rate / 100
    Float.round(price + tax, 2)
  end

  def total(price, discount_pct, tax_rate) do
    price
    |> apply_discount(discount_pct)
    |> apply_tax(tax_rate)
  end
end

# Order service uses the real pure calculator — no mock needed
defmodule MOCK009.OrderService do
  def calculate_order_total(base_price, discount_pct, tax_rate) do
    MOCK009.PriceCalculator.total(base_price, discount_pct, tax_rate)
  end
end

# Test the pure calculator directly — fast, clear, no mocking needed
defmodule MOCK009.PriceCalculatorTest do
  use ExUnit.Case, async: true

  test "apply_discount reduces price by percentage" do
    assert MOCK009.PriceCalculator.apply_discount(100.0, 10) == 90.0
    assert MOCK009.PriceCalculator.apply_discount(200.0, 25) == 150.0
  end

  test "apply_discount of 0% returns original price" do
    assert MOCK009.PriceCalculator.apply_discount(99.99, 0) == 99.99
  end

  test "apply_tax adds tax to price" do
    assert MOCK009.PriceCalculator.apply_tax(100.0, 8.0) == 108.0
  end

  test "total applies discount then tax" do
    # 100 -> 10% discount -> 90 -> 8% tax -> 97.20
    assert MOCK009.PriceCalculator.total(100.0, 10, 8.0) == 97.2
  end
end

# Test the order service with the REAL calculator — no mock
defmodule MOCK009.OrderServiceTest do
  use ExUnit.Case, async: true

  test "calculate_order_total integrates discount and tax correctly" do
    # Real PriceCalculator runs — actual logic is exercised
    result = MOCK009.OrderService.calculate_order_total(100.0, 10, 8.0)
    assert result == 97.2
  end
end
