# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule TestWithClauseErrorsProcessor do
  def fetch_order(1), do: {:ok, %{id: 1, user_id: 10, total: 100}}
  def fetch_order(2), do: {:ok, %{id: 2, user_id: 99, total: 50}}
  def fetch_order(_), do: {:error, :order_not_found}

  def fetch_user(10), do: {:ok, %{id: 10, card: :valid}}
  def fetch_user(20), do: {:ok, %{id: 20, card: :invalid}}
  def fetch_user(_), do: {:error, :user_not_found}

  def charge_card(%{card: :valid}, _amount), do: {:ok, :charged}
  def charge_card(%{card: :invalid}, _amount), do: {:error, :payment_failed}

  def process_order(order_id) do
    with {:ok, order} <- fetch_order(order_id),
         {:ok, user}  <- fetch_user(order.user_id),
         {:ok, _}     <- charge_card(user, order.total) do
      {:ok, :processed}
    end
  end
end

defmodule TestWithClauseErrorsGoodTest do
  use ExUnit.Case, async: true

  alias TestWithClauseErrorsProcessor, as: P

  describe "process_order/1" do
    test "returns {:ok, :processed} when all steps succeed" do
      assert {:ok, :processed} = P.process_order(1)
    end

    test "returns {:error, :order_not_found} when order does not exist" do
      assert {:error, :order_not_found} = P.process_order(999)
    end

    test "returns {:error, :user_not_found} when order's user is missing" do
      # order_id 2 has user_id 99, which fetch_user/1 returns :not_found for
      assert {:error, :user_not_found} = P.process_order(2)
    end
  end
end
