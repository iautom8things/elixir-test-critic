# EXPECTED: passes
# BAD PRACTICE: Only mock tests exist. The real implementation (FormalGreeter)
# is never tested. If FormalGreeter has a bug or diverges from what the mock
# returns, these tests will pass while production silently breaks.
Mix.install([:mox])

ExUnit.start(autorun: true)

defmodule MOCK008Bad.GreeterBehaviour do
  @callback greet(name :: String.t()) :: {:ok, String.t()} | {:error, term()}
end

Mox.defmock(MOCK008Bad.GreeterMock, for: MOCK008Bad.GreeterBehaviour)

# Real implementation exists but is NEVER tested
defmodule MOCK008Bad.FormalGreeter do
  @behaviour MOCK008Bad.GreeterBehaviour

  @impl true
  def greet(name) when is_binary(name) and byte_size(name) > 0 do
    # BUG: accidentally returns "Greetings" instead of "Good day"
    # but no integration test will catch this
    {:ok, "Greetings, #{name}."}
  end
  def greet(_), do: {:error, :invalid_name}
end

defmodule MOCK008Bad.WelcomeService do
  def welcome(greeter, name) do
    case greeter.greet(name) do
      {:ok, message} -> {:ok, "Welcome: #{message}"}
      error -> error
    end
  end
end

defmodule MOCK008Bad.WelcomeServiceTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  # Only mock tests — real FormalGreeter is never called
  test "welcome wraps greeter message (mock only)" do
    expect(MOCK008Bad.GreeterMock, :greet, 1, fn "Alice" ->
      {:ok, "Good day, Alice."}
    end)

    assert {:ok, "Welcome: Good day, Alice."} ==
             MOCK008Bad.WelcomeService.welcome(MOCK008Bad.GreeterMock, "Alice")
  end

  # No @tag :integration test, no test for MOCK008Bad.FormalGreeter
  # The bug in FormalGreeter (returns "Greetings" instead of "Good day")
  # will go undetected until production
end
