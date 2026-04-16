# EXPECTED: passes
Mix.install([:stream_data])

ExUnit.start(autorun: true)

defmodule MyApp.RoundtripGoodTest.Token do
  # Simple base64-based token encoding/decoding
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

defmodule MyApp.RoundtripGoodTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias MyApp.RoundtripGoodTest.Token

  # Keep specific example tests for known values
  test "encodes 42 to the expected base64 string" do
    assert Token.encode(42) == Base.encode64("42")
  end

  # Roundtrip property — covers 0, large numbers, boundary values automatically
  property "encode/decode roundtrip for any non-negative integer" do
    check all id <- StreamData.non_negative_integer() do
      assert {:ok, ^id} = id |> Token.encode() |> Token.decode()
    end
  end

  # String roundtrip using standard library
  property "URI encode/decode is a roundtrip for printable strings" do
    check all s <- StreamData.string(:printable) do
      assert URI.decode(URI.encode(s)) == s
    end
  end

  # Base64 roundtrip
  property "Base64 encode/decode is a roundtrip for any binary" do
    check all data <- StreamData.binary() do
      assert Base.decode64!(Base.encode64(data)) == data
    end
  end
end
