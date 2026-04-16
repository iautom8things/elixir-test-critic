# EXPECTED: passes
# BAD PRACTICE: Sets expectations with Mox.expect but never calls verify_on_exit!
# or Mox.verify!/1. The expectations are silently ignored — even if the code
# under test never calls the mock, the test passes. This creates a false sense
# of security: you think you're verifying the call happened, but you're not.
Mix.install([:mox])

ExUnit.start(autorun: true)

defmodule MOCK004Bad.SMSBehaviour do
  @callback send_sms(to :: String.t(), body :: String.t()) :: :ok | {:error, term()}
end

Mox.defmock(MOCK004Bad.SMSMock, for: MOCK004Bad.SMSBehaviour)

defmodule MOCK004Bad.Notifier do
  def notify_user(sms_adapter, phone, message) do
    sms_adapter.send_sms(phone, message)
  end

  # Imagine a bug introduced here: this version forgets to call the adapter
  def notify_user_buggy(_sms_adapter, _phone, _message) do
    # oops, forgot to send the SMS
    :ok
  end
end

defmodule MOCK004Bad.VerifyOnExitBadTest do
  use ExUnit.Case, async: true

  import Mox

  # Missing: setup :verify_on_exit!
  # Without this, unmet expectations are silently ignored

  test "notify_user sends SMS (expectation never verified)" do
    # This expect says "send_sms must be called exactly once"
    # But without verify_on_exit!, Mox never checks if it was satisfied
    expect(MOCK004Bad.SMSMock, :send_sms, 1, fn _phone, _body -> :ok end)

    # Even if we call the buggy version that never calls the mock,
    # this test will PASS because expectations are not verified on exit
    result = MOCK004Bad.Notifier.notify_user_buggy(
      MOCK004Bad.SMSMock,
      "+15551234567",
      "Hello!"
    )

    assert result == :ok
    # The SMS was never sent, but this test is green. Silent failure.
  end
end
