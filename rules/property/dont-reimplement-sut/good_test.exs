# EXPECTED: passes
Mix.install([:stream_data])

ExUnit.start(autorun: true)

defmodule MyApp.DontReimplementGoodTest.Pricing do
  def discount(:standard, amount), do: trunc(amount * 0.05)
  def discount(:vip, amount), do: trunc(amount * 0.15)
  def discount(:platinum, amount), do: trunc(amount * 0.25)
end

defmodule MyApp.DontReimplementGoodTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MyApp.DontReimplementGoodTest.Pricing

  # GOOD: Tests the invariant (range), not the formula
  property "discount is always non-negative and never exceeds purchase amount" do
    check all amount <- StreamData.integer(1..10_000),
              tier <- StreamData.member_of([:standard, :vip, :platinum]) do
      discount = Pricing.discount(tier, amount)
      assert discount >= 0
      assert discount <= amount
    end
  end

  # GOOD: Tests ordering between tiers — catches swapped tier logic
  property "higher tiers always receive a greater or equal discount" do
    check all amount <- StreamData.integer(1..10_000) do
      assert Pricing.discount(:platinum, amount) >= Pricing.discount(:vip, amount)
      assert Pricing.discount(:vip, amount) >= Pricing.discount(:standard, amount)
    end
  end

  # GOOD: Tests monotonic growth — discount grows with amount for same tier
  property "discount grows as purchase amount grows for the same tier" do
    check all small <- StreamData.integer(1..100),
              large <- StreamData.integer(101..1000) do
      assert Pricing.discount(:vip, large) >= Pricing.discount(:vip, small)
    end
  end
end
