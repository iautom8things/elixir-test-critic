# EXPECTED: passes
Mix.install([:stream_data])

ExUnit.start(autorun: true)

defmodule MyApp.WhenToUsePropertiesGoodTest.Pricing do
  def discount(:standard, amount), do: trunc(amount * 0.05)
  def discount(:vip, amount), do: trunc(amount * 0.15)
  def discount(:platinum, amount), do: trunc(amount * 0.25)
end

defmodule MyApp.WhenToUsePropertiesGoodTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MyApp.WhenToUsePropertiesGoodTest.Pricing

  # GOOD: Example test for a specific business rule
  test "VIP discount is 15% of purchase amount" do
    assert Pricing.discount(:vip, 100) == 15
    assert Pricing.discount(:vip, 200) == 30
  end

  test "standard discount is 5% of purchase amount" do
    assert Pricing.discount(:standard, 100) == 5
  end

  # GOOD: Property test for a general invariant — discount is always valid
  property "discount is always between 0 and the purchase amount" do
    check all amount <- StreamData.integer(1..10_000),
              tier <- StreamData.member_of([:standard, :vip, :platinum]) do
      discount = Pricing.discount(tier, amount)
      assert discount >= 0
      assert discount <= amount
    end
  end

  # GOOD: Property test for ordering invariant
  property "sorted list is always non-descending" do
    check all list <- StreamData.list_of(StreamData.integer()) do
      sorted = Enum.sort(list)
      # Each element should be <= the next element
      sorted
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] -> assert a <= b end)
    end
  end
end
