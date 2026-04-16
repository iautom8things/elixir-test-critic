# EXPECTED: passes
# BAD PRACTICE: Uses a hand-rolled fake HTTP response instead of Req.Test.
# The real Req pipeline (JSON decoding, response normalization, middleware) never
# runs. Tests are coupled to the internal shape of the fake response map rather
# than the actual decoded response structure that Req would produce.
Mix.install([:req])

ExUnit.start(autorun: true)

# Hand-rolled fake that bypasses Req entirely
defmodule MOCK006Bad.FakeReq do
  def get(_opts) do
    body = %{"temperature" => 22, "city" => "London"}
    {:ok, %{status: 200, body: body}}
  end
end

# The real client, but with a seam that accepts a fake http module
defmodule MOCK006Bad.WeatherClient do
  def get_temperature(_city, http \\ MOCK006Bad.FakeReq) do
    case http.get([]) do
      {:ok, %{status: 200, body: %{"temperature" => temp}}} -> {:ok, temp}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule MOCK006Bad.ReqTestBadTest do
  use ExUnit.Case, async: true

  test "returns temperature (but Req pipeline never runs)" do
    # FakeReq is used — no real Req processing, no JSON decoding via Req,
    # no middleware chain, no actual HTTP behaviour tested
    assert {:ok, 22} = MOCK006Bad.WeatherClient.get_temperature("London")
  end

  test "no Req.Test used — stubbing at wrong level" do
    # The test works, but it bypasses all of Req's features.
    # If the client starts using Req middleware (auth headers, retries),
    # none of that would be exercised here.
    assert {:ok, _} = MOCK006Bad.WeatherClient.get_temperature("London", MOCK006Bad.FakeReq)
  end
end
