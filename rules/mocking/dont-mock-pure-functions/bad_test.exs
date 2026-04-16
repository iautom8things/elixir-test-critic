# EXPECTED: passes
# BAD PRACTICE: Mocks a pure price calculator to test the order service.
# The real PriceCalculator logic is never exercised. If PriceCalculator has
# a bug (wrong formula, incorrect rounding), this test will never catch it.
# The test only verifies that OrderService passes arguments to some function
# and returns whatever that function returns — which is completely trivial.
Mix.install([:mox])

ExUnit.start(autorun: true)

# Behaviour defined for a pure function — smell: why does a pure function need a behaviour?
defmodule MOCK009Bad.PriceCalculatorBehaviour do
  @callback total(price :: float(), discount_pct :: number(), tax_rate :: number()) :: float()
end

Mox.defmock(MOCK009Bad.PriceCalculatorMock, for: MOCK009Bad.PriceCalculatorBehaviour)

# Real implementation — but it's never tested in this file
defmodule MOCK009Bad.PriceCalculator do
  @behaviour MOCK009Bad.PriceCalculatorBehaviour

  @impl true
  def total(price, discount_pct, tax_rate) do
    discounted = price * (1 - discount_pct / 100)
    Float.round(discounted * (1 + tax_rate / 100), 2)
  end
end

defmodule MOCK009Bad.OrderService do
  def calculate_order_total(calculator, base_price, discount_pct, tax_rate) do
    calculator.total(base_price, discount_pct, tax_rate)
  end
end

defmodule MOCK009Bad.OrderServiceTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "calculate_order_total delegates to calculator (pure function mocked)" do
    # The mock returns a hardcoded value — the real formula is never tested
    expect(MOCK009Bad.PriceCalculatorMock, :total, 1, fn 100.0, 10, 8.0 ->
      97.2
    end)

    result =
      MOCK009Bad.OrderService.calculate_order_total(
        MOCK009Bad.PriceCalculatorMock,
        100.0,
        10,
        8.0
      )

    # This assertion is trivially true — the mock was programmed to return 97.2
    assert result == 97.2

    # If PriceCalculator.total had a bug and returned 97.0, we'd never know
    # because the real function is never called in this test
  end
end
