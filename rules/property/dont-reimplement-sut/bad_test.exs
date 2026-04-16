# EXPECTED: passes
# BAD PRACTICE: Property test that reimplements the same formula as the SUT.
# Both sides of the assertion contain the same logic — if the formula is wrong,
# both are wrong and the test still passes. Zero additional confidence.
Mix.install([:stream_data])

ExUnit.start(autorun: true)

defmodule MyApp.DontReimplementBadTest.Pricing do
  # Hypothetically buggy: should be 0.20 for VIP but uses 0.15
  def discount(:vip, amount), do: trunc(amount * 0.15)
  def discount(:standard, amount), do: trunc(amount * 0.05)
  def discount(:platinum, amount), do: trunc(amount * 0.25)
end

defmodule MyApp.DontReimplementBadTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MyApp.DontReimplementBadTest.Pricing

  # BAD: Reimplements the exact same formula in the assertion.
  # If the formula is 0.15 when it should be 0.20, this test passes anyway.
  # The test provides zero confidence that the formula is correct.
  property "BAD: vip discount equals amount * 0.15" do
    check all amount <- StreamData.integer(1..10_000) do
      # The assertion IS the implementation — same bug passes the same test
      assert Pricing.discount(:vip, amount) == trunc(amount * 0.15)
    end
  end

  # BAD: Reimplementing step-by-step inside the property body
  property "BAD: standard discount reimplemented inline" do
    check all amount <- StreamData.integer(1..10_000) do
      expected = amount |> Kernel.*(0.05) |> trunc()
      # This is just running Pricing.discount(:standard, amount) twice
      assert Pricing.discount(:standard, amount) == expected
    end
  end
end
