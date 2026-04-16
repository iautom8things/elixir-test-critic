# EXPECTED: passes
Mix.install([:mox])

ExUnit.start(autorun: true)

defmodule MOCK003.AuthBehaviour do
  @callback fetch_token() :: {:ok, String.t()} | {:error, term()}
end

defmodule MOCK003.PaymentBehaviour do
  @callback charge(amount :: pos_integer()) :: {:ok, String.t()} | {:error, term()}
end

Mox.defmock(MOCK003.AuthMock, for: MOCK003.AuthBehaviour)
Mox.defmock(MOCK003.PaymentMock, for: MOCK003.PaymentBehaviour)

defmodule MOCK003.OrderService do
  def create_and_charge(auth, payment, amount) do
    with {:ok, _token} <- auth.fetch_token(),
         {:ok, txn_id} <- payment.charge(amount) do
      {:ok, txn_id}
    end
  end
end

defmodule MOCK003.ExpectVsStubGoodTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  setup do
    # stub for setup: we need auth to work, but don't care how many times it's called
    stub(MOCK003.AuthMock, :fetch_token, fn -> {:ok, "test-token"} end)
    :ok
  end

  test "charges payment gateway exactly once" do
    # expect for the outcome: verify the payment call was made exactly once
    expect(MOCK003.PaymentMock, :charge, 1, fn 500 -> {:ok, "txn_abc"} end)

    assert {:ok, "txn_abc"} ==
             MOCK003.OrderService.create_and_charge(
               MOCK003.AuthMock,
               MOCK003.PaymentMock,
               500
             )
  end

  test "returns error when payment fails" do
    expect(MOCK003.PaymentMock, :charge, 1, fn _amount -> {:error, :declined} end)

    assert {:error, :declined} ==
             MOCK003.OrderService.create_and_charge(
               MOCK003.AuthMock,
               MOCK003.PaymentMock,
               500
             )
  end

  test "returns error when auth fails (payment is never called)" do
    # Override the stub with an error for this specific test
    stub(MOCK003.AuthMock, :fetch_token, fn -> {:error, :unauthorized} end)
    # Expect payment to NOT be called when auth fails
    expect(MOCK003.PaymentMock, :charge, 0, fn _ -> :ok end)

    assert {:error, :unauthorized} ==
             MOCK003.OrderService.create_and_charge(
               MOCK003.AuthMock,
               MOCK003.PaymentMock,
               500
             )
  end
end
