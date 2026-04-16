# EXPECTED: passes
Mix.install([:mox])

ExUnit.start(autorun: true)

# Boundary behaviour: the external email service
defmodule MOCK002.EmailBehaviour do
  @callback deliver(to :: String.t(), subject :: String.t(), body :: String.t()) ::
              {:ok, String.t()} | {:error, term()}
end

Mox.defmock(MOCK002.EmailMock, for: MOCK002.EmailBehaviour)

# Internal pure module — NOT mocked, tested directly
defmodule MOCK002.EmailFormatter do
  def welcome_subject(name), do: "Welcome, #{name}!"
  def welcome_body(name), do: "Hi #{name}, thanks for signing up."
end

# Module under test: uses pure formatter + boundary email service
defmodule MOCK002.UserOnboarding do
  def send_welcome(email_adapter, name, email_address) do
    subject = MOCK002.EmailFormatter.welcome_subject(name)
    body = MOCK002.EmailFormatter.welcome_body(name)
    email_adapter.deliver(email_address, subject, body)
  end
end

defmodule MOCK002.MockAtBoundaryGoodTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "send_welcome uses real formatter and mocked email boundary" do
    # Only the external email boundary is mocked
    # The real EmailFormatter.welcome_subject and welcome_body actually run
    MOCK002.EmailMock
    |> expect(:deliver, fn "alice@example.com", subject, body ->
      assert subject == "Welcome, Alice!"
      assert body == "Hi Alice, thanks for signing up."
      {:ok, "msg_001"}
    end)

    assert {:ok, "msg_001"} ==
             MOCK002.UserOnboarding.send_welcome(
               MOCK002.EmailMock,
               "Alice",
               "alice@example.com"
             )
  end

  test "internal formatter can be tested directly without any mock" do
    # Pure internal module — no mock needed
    assert MOCK002.EmailFormatter.welcome_subject("Bob") == "Welcome, Bob!"
    assert MOCK002.EmailFormatter.welcome_body("Bob") =~ "Hi Bob"
  end
end
