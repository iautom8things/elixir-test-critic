# EXPECTED: passes
# BAD PRACTICE: Using property tests for specific business rules
# (where example tests are clearer), and using example tests where
# properties would catch more bugs.
Mix.install([:stream_data])

ExUnit.start(autorun: true)

defmodule MyApp.WhenToUsePropertiesBadTest.Pricing do
  def discount(:standard, amount), do: trunc(amount * 0.05)
  def discount(:vip, amount), do: trunc(amount * 0.15)
  def discount(:platinum, amount), do: trunc(amount * 0.25)
end

defmodule MyApp.WhenToUsePropertiesBadTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MyApp.WhenToUsePropertiesBadTest.Pricing

  # BAD: Property test asserting a specific value — this is an example test in disguise.
  # It runs 100 iterations and checks the same formula each time, providing no extra value.
  # Use `test "VIP discount is 15%"` instead.
  property "BAD: vip discount equals amount * 0.15 (reimplements the formula)" do
    check all amount <- StreamData.integer(1..1000) do
      # Reimplementing the exact calculation — if Pricing has the same bug, this passes.
      # No invariant is being tested.
      assert Pricing.discount(:vip, amount) == trunc(amount * 0.15)
    end
  end

  # BAD: 10 example tests all checking the same structural property.
  # A single property test would be clearer and cover far more cases.
  test "BAD: sorted list of 1 element is in order" do
    assert Enum.sort([5]) == [5]
  end

  test "BAD: sorted list of 2 elements is in order" do
    assert Enum.sort([2, 1]) == [1, 2]
  end

  test "BAD: sorted list of 3 elements is in order" do
    assert Enum.sort([3, 1, 2]) == [1, 2, 3]
  end
  # ... imagine 7 more of these — all testing the same invariant with specific examples
end
