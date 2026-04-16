# EXPECTED: passes
# BAD PRACTICE: Only testing encode/decode with a fixed set of hand-picked examples.
# These tests pass but miss Unicode, empty strings, large values, and special chars.
Mix.install([:stream_data])

ExUnit.start(autorun: true)

defmodule MyApp.RoundtripBadTest.Token do
  def encode(id) when is_integer(id) and id >= 0 do
    id |> Integer.to_string() |> Base.encode64()
  end

  def decode(token) when is_binary(token) do
    with {:ok, decoded} <- Base.decode64(token),
         {id, ""} <- Integer.parse(decoded) do
      {:ok, id}
    else
      _ -> {:error, :invalid_token}
    end
  end
end

defmodule MyApp.RoundtripBadTest do
  use ExUnit.Case, async: true

  alias MyApp.RoundtripBadTest.Token

  # BAD: Only a small set of hand-picked examples.
  # What about id=0? id=max_int? What if encode introduces whitespace for large numbers?
  # You'll never know from these tests.
  test "encodes 1" do
    assert Token.encode(1) == Base.encode64("1")
  end

  test "encodes 42" do
    assert Token.encode(42) == Base.encode64("42")
  end

  test "decodes token for id 42" do
    token = Token.encode(42)
    assert Token.decode(token) == {:ok, 42}
  end

  # These three tests look comprehensive but cover only 2 values out of infinite space.
  # A roundtrip property test would cover the whole domain with zero extra tests.
end
