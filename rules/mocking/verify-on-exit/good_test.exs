# EXPECTED: passes
Mix.install([:mox])

ExUnit.start(autorun: true)

defmodule MOCK004.SMSBehaviour do
  @callback send_sms(to :: String.t(), body :: String.t()) :: :ok | {:error, term()}
end

Mox.defmock(MOCK004.SMSMock, for: MOCK004.SMSBehaviour)

defmodule MOCK004.Notifier do
  def notify_user(sms_adapter, phone, message) do
    sms_adapter.send_sms(phone, message)
  end
end

defmodule MOCK004.VerifyOnExitGoodTest do
  use ExUnit.Case, async: true

  import Mox

  # verify_on_exit! ensures every expect is satisfied after each test
  setup :verify_on_exit!

  test "notify_user sends exactly one SMS" do
    expect(MOCK004.SMSMock, :send_sms, 1, fn "+15551234567", "Hello!" -> :ok end)

    assert :ok ==
             MOCK004.Notifier.notify_user(MOCK004.SMSMock, "+15551234567", "Hello!")

    # After this test, verify_on_exit! checks: was send_sms called exactly once?
    # If it wasn't, the test fails with a clear message about unsatisfied expectations.
  end

  test "notify_user is called twice when there are two recipients" do
    expect(MOCK004.SMSMock, :send_sms, 2, fn _phone, "Alert!" -> :ok end)

    MOCK004.Notifier.notify_user(MOCK004.SMSMock, "+15550001111", "Alert!")
    MOCK004.Notifier.notify_user(MOCK004.SMSMock, "+15550002222", "Alert!")
    # verify_on_exit! confirms both calls happened
  end

  test "stub does not require verify (count not tracked)" do
    # stub is for setup scenarios where call count is irrelevant
    stub(MOCK004.SMSMock, :send_sms, fn _phone, _body -> :ok end)

    MOCK004.Notifier.notify_user(MOCK004.SMSMock, "+15550003333", "msg")
    # No assertion on call count — stub just provides the response
    assert true
  end
end
