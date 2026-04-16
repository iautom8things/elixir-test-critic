# EXPECTED: passes
# BAD PRACTICE: Mocks an internal pure formatting module instead of only
# mocking the external boundary. The test never exercises the real formatting
# logic, making it useless for catching formatter bugs. Any change to the
# formatter will not break this test, which defeats the purpose of testing.
Mix.install([:mox])

ExUnit.start(autorun: true)

# Internal pure module
defmodule MOCK002Bad.EmailFormatter do
  @callback welcome_subject(String.t()) :: String.t()
  @callback welcome_body(String.t()) :: String.t()
end

# Mocking an internal module that has no I/O and needs no mock
Mox.defmock(MOCK002Bad.EmailFormatterMock, for: MOCK002Bad.EmailFormatter)

defmodule MOCK002Bad.RealEmailFormatter do
  @behaviour MOCK002Bad.EmailFormatter
  @impl true
  def welcome_subject(name), do: "Welcome, #{name}!"
  @impl true
  def welcome_body(name), do: "Hi #{name}, thanks for signing up."
end

defmodule MOCK002Bad.UserOnboarding do
  def send_welcome(formatter, name) do
    subject = formatter.welcome_subject(name)
    body = formatter.welcome_body(name)
    # Imagine this sends an email in production
    {subject, body}
  end
end

defmodule MOCK002Bad.MockAtBoundaryBadTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "send_welcome builds subject and body (but never tests real logic)" do
    # Mocking the internal formatter — real formatting code never runs
    MOCK002Bad.EmailFormatterMock
    |> expect(:welcome_subject, fn "Alice" -> "Welcome, Alice!" end)
    |> expect(:welcome_body, fn "Alice" -> "Hi Alice, thanks for signing up." end)

    {subject, body} =
      MOCK002Bad.UserOnboarding.send_welcome(MOCK002Bad.EmailFormatterMock, "Alice")

    # These assertions tell us nothing about the real formatter
    assert subject == "Welcome, Alice!"
    assert body =~ "Hi Alice"
  end
end
