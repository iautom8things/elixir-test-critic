# EXPECTED: passes
Mix.install([:req, :plug])

ExUnit.start(autorun: true)

defmodule MOCK006.WeatherClient do
  @doc """
  Fetches weather data. Pass plug: {Req.Test, StubName} in opts for testing.
  """
  def get_temperature(city, req_options \\ []) do
    base_options = [
      url: "http://api.weather.example.com/current",
      params: [city: city],
      retry: false
    ]

    case Req.get(base_options ++ req_options) do
      {:ok, %{status: 200, body: %{"temperature" => temp}}} -> {:ok, temp}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{status: status}} -> {:error, {:unexpected_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule MOCK006.ReqTestGoodTest do
  use ExUnit.Case, async: true

  test "returns temperature when API responds with 200" do
    # Req.Test.stub registers a named stub handler
    # Use plug: {Req.Test, StubName} to route the request to the stub
    Req.Test.stub(MOCK006.WeatherClient, fn conn ->
      Req.Test.json(conn, %{"temperature" => 22, "city" => "London"})
    end)

    assert {:ok, 22} =
             MOCK006.WeatherClient.get_temperature(
               "London",
               plug: {Req.Test, MOCK006.WeatherClient}
             )
  end

  test "returns :not_found when API responds with 404" do
    Req.Test.stub(MOCK006.WeatherClient, fn conn ->
      Plug.Conn.resp(conn, 404, "")
    end)

    assert {:error, :not_found} =
             MOCK006.WeatherClient.get_temperature(
               "UnknownCity",
               plug: {Req.Test, MOCK006.WeatherClient}
             )
  end

  test "returns error for unexpected status codes" do
    Req.Test.stub(MOCK006.WeatherClient, fn conn ->
      Plug.Conn.resp(conn, 503, "")
    end)

    assert {:error, {:unexpected_status, 503}} =
             MOCK006.WeatherClient.get_temperature(
               "London",
               plug: {Req.Test, MOCK006.WeatherClient}
             )
  end
end
