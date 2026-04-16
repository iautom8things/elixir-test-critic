# EXPECTED: passes
# BAD PRACTICE: Only the happy path of the with expression is tested.
# The three failure paths (order not found, user not found, charge failed) are
# completely untested. Regressions in any of those paths will not be caught.
Mix.install([])

ExUnit.start(autorun: true)

defmodule TestWithClauseErrorsBadProcessor do
  def fetch_order(1), do: {:ok, %{id: 1, user_id: 10, total: 100}}
  def fetch_order(_), do: {:error, :order_not_found}

  def fetch_user(10), do: {:ok, %{id: 10, card: :valid}}
  def fetch_user(_), do: {:error, :user_not_found}

  def charge_card(%{card: :valid}, _amount), do: {:ok, :charged}
  def charge_card(_, _), do: {:error, :payment_failed}

  def process_order(order_id) do
    with {:ok, order} <- fetch_order(order_id),
         {:ok, user}  <- fetch_user(order.user_id),
         {:ok, _}     <- charge_card(user, order.total) do
      {:ok, :processed}
    end
  end
end

defmodule TestWithClauseErrorsBadTest do
  use ExUnit.Case, async: true

  alias TestWithClauseErrorsBadProcessor, as: P

  describe "process_order/1" do
    # Only the happy path — three error paths are not tested at all
    test "processes a valid order" do
      assert {:ok, :processed} = P.process_order(1)
    end

    # Missing: test for {:error, :order_not_found}
    # Missing: test for {:error, :user_not_found}
    # Missing: test for {:error, :payment_failed}
  end
end
