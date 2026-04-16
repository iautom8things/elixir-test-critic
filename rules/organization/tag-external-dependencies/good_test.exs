# EXPECTED: passes
# Demonstrates: using @moduletag and @tag to mark tests with external dependencies.
# Tagged tests can be excluded from fast local runs with ExUnit.configure(exclude: [...]).
Mix.install([])

ExUnit.start(autorun: true)

# Simulate external payment adapter
defmodule MyApp.TagExternalGoodTest.Payments do
  def valid_card?(number), do: String.length(number) == 16
  def charge(_token, amount) when amount > 0, do: {:ok, %{id: "ch_123", amount: amount}}
  def charge(_token, _amount), do: {:error, :invalid_amount}
end

defmodule MyApp.TagExternalGoodTest do
  use ExUnit.Case, async: true

  alias MyApp.TagExternalGoodTest.Payments

  # GOOD: Unit tests — no external dependency, no tag needed, run always
  test "valid_card? returns false for short card numbers" do
    refute Payments.valid_card?("1234")
  end

  test "valid_card? returns true for 16-digit number" do
    assert Payments.valid_card?("4111111111111111")
  end

  # GOOD: Tagged as :external_api — can be excluded from fast runs
  # In a real app, this would hit Stripe's actual API.
  # With ExUnit.configure(exclude: [:external_api]), this is skipped unless
  # the user passes --include external_api.
  @tag :external_api
  test "charge/2 returns ok for valid token and positive amount" do
    # In a real test, this would call the live Stripe API
    # Here we simulate the concept — the tag is what matters for this rule
    assert {:ok, charge} = Payments.charge("tok_visa", 1000)
    assert charge.amount == 1000
  end

  @tag :external_api
  test "charge/2 returns error for zero amount" do
    assert {:error, :invalid_amount} = Payments.charge("tok_visa", 0)
  end
end
