# EXPECTED: passes
# BAD PRACTICE: Tests that require external resources but have no tags.
# In a real environment, these would fail without credentials or network access,
# slow down CI, and give no way to selectively exclude them.
Mix.install([])

ExUnit.start(autorun: true)

defmodule MyApp.TagExternalBadTest.Payments do
  def valid_card?(number), do: String.length(number) == 16
  def charge(_token, amount) when amount > 0, do: {:ok, %{id: "ch_123", amount: amount}}
  def charge(_token, _amount), do: {:error, :invalid_amount}
end

defmodule MyApp.TagExternalBadTest do
  use ExUnit.Case, async: false
  # BAD: No @moduletag :external_api
  # These tests hit external services but there's no way to exclude them
  # from fast local runs or CI unit test stages without editing the file.

  alias MyApp.TagExternalBadTest.Payments

  test "valid card is 16 digits" do
    assert Payments.valid_card?("4111111111111111")
  end

  test "BAD: charge hits live API — no tag, always runs, may fail without credentials" do
    # In a real app: would call Stripe with STRIPE_API_KEY from env.
    # Without the key in CI, this test fails with a confusing error.
    # Without a :external_api tag, there's no way to skip it selectively.
    assert {:ok, _} = Payments.charge("tok_visa", 500)
  end

  test "BAD: another external call — same problem" do
    # Developers must either edit this file or run all tests including slow ones.
    # No granularity without tags.
    assert {:error, :invalid_amount} = Payments.charge("tok_visa", 0)
  end
end
