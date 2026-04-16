# EXPECTED: passes
# BAD PRACTICE: Uses expect in setup (brittle — breaks if call count changes)
# and stub for the outcome verification (no guarantee payment was called).
# The result: a test that passes even if the payment is never charged.
Mix.install([:mox])

ExUnit.start(autorun: true)

defmodule MOCK003Bad.AuthBehaviour do
  @callback fetch_token() :: {:ok, String.t()} | {:error, term()}
end

defmodule MOCK003Bad.PaymentBehaviour do
  @callback charge(amount :: pos_integer()) :: {:ok, String.t()} | {:error, term()}
end

Mox.defmock(MOCK003Bad.AuthMock, for: MOCK003Bad.AuthBehaviour)
Mox.defmock(MOCK003Bad.PaymentMock, for: MOCK003Bad.PaymentBehaviour)

defmodule MOCK003Bad.OrderService do
  def create_and_charge(auth, payment, amount) do
    with {:ok, _token} <- auth.fetch_token(),
         {:ok, txn_id} <- payment.charge(amount) do
      {:ok, txn_id}
    end
  end
end

defmodule MOCK003Bad.ExpectVsStubBadTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  setup do
    # BAD: expect in setup with count=1 — will break if the call path ever
    # fetches the token more than once (e.g., for refresh logic)
    expect(MOCK003Bad.AuthMock, :fetch_token, 1, fn -> {:ok, "test-token"} end)
    :ok
  end

  test "order creation flow" do
    # BAD: stub for the important outcome — no verification that charge was called
    # If create_and_charge is refactored to skip charging, this test still passes
    stub(MOCK003Bad.PaymentMock, :charge, fn _amount -> {:ok, "txn_abc"} end)

    result =
      MOCK003Bad.OrderService.create_and_charge(
        MOCK003Bad.AuthMock,
        MOCK003Bad.PaymentMock,
        500
      )

    assert result == {:ok, "txn_abc"}
    # No verification that the payment boundary was actually exercised
  end
end
