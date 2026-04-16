# EXPECTED: passes
Mix.install([:mox])

ExUnit.start(autorun: true)

# The contract
defmodule MOCK008.GreeterBehaviour do
  @callback greet(name :: String.t()) :: {:ok, String.t()} | {:error, term()}
end

Mox.defmock(MOCK008.GreeterMock, for: MOCK008.GreeterBehaviour)

# The real implementation
defmodule MOCK008.FormalGreeter do
  @behaviour MOCK008.GreeterBehaviour

  @impl true
  def greet(name) when is_binary(name) and byte_size(name) > 0 do
    {:ok, "Good day, #{name}."}
  end
  def greet(_), do: {:error, :invalid_name}
end

# The module under test
defmodule MOCK008.WelcomeService do
  def welcome(greeter, name) do
    case greeter.greet(name) do
      {:ok, message} -> {:ok, "Welcome: #{message}"}
      error -> error
    end
  end
end

# Mock-based unit tests — fast, isolated
defmodule MOCK008.WelcomeServiceTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "welcome wraps greeter message" do
    expect(MOCK008.GreeterMock, :greet, 1, fn "Alice" ->
      {:ok, "Good day, Alice."}
    end)

    assert {:ok, "Welcome: Good day, Alice."} ==
             MOCK008.WelcomeService.welcome(MOCK008.GreeterMock, "Alice")
  end

  test "welcome propagates greeter error" do
    expect(MOCK008.GreeterMock, :greet, 1, fn _ -> {:error, :invalid_name} end)

    assert {:error, :invalid_name} ==
             MOCK008.WelcomeService.welcome(MOCK008.GreeterMock, "")
  end
end

# Integration test — verifies the REAL implementation fulfills the contract
# Tagged :integration so it can be selectively run
defmodule MOCK008.FormalGreeterIntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  test "real FormalGreeter returns correctly formatted greeting" do
    assert {:ok, "Good day, Bob."} == MOCK008.FormalGreeter.greet("Bob")
  end

  test "real FormalGreeter rejects empty name" do
    assert {:error, :invalid_name} == MOCK008.FormalGreeter.greet("")
  end

  test "real implementation satisfies the behaviour contract" do
    # Verify that the behaviour's callbacks are all implemented
    assert function_exported?(MOCK008.FormalGreeter, :greet, 1)
  end
end
