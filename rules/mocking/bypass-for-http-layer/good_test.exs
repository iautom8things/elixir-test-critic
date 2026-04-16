# EXPECTED: passes
Mix.install([:bypass, :plug])

Application.ensure_all_started(:inets)

ExUnit.start(autorun: true)

# A simple HTTP client module that uses :httpc (built-in, no extra dep)
defmodule MOCK005.SimpleHttpClient do
  @doc "Fetches a URL and returns {:ok, status, body} or {:error, reason}"
  def get(url) do
    url_charlist = String.to_charlist(url)
    case :httpc.request(:get, {url_charlist, []}, [], []) do
      {:ok, {{_version, status, _reason}, _headers, body}} ->
        {:ok, status, List.to_string(body)}
      {:error, reason} ->
        {:error, reason}
    end
  end
end

defmodule MOCK005.BypassGoodTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    %{bypass: bypass}
  end

  test "client handles 200 response correctly", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/status", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, ~s({"status": "ok"}))
    end)

    url = "http://localhost:#{bypass.port}/api/status"
    assert {:ok, 200, body} = MOCK005.SimpleHttpClient.get(url)
    assert body =~ "ok"
  end

  test "client receives 404 response from Bypass", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/missing", fn conn ->
      Plug.Conn.resp(conn, 404, "not found")
    end)

    url = "http://localhost:#{bypass.port}/api/missing"
    assert {:ok, 404, _body} = MOCK005.SimpleHttpClient.get(url)
  end

  test "client receives 500 response from Bypass", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/broken", fn conn ->
      Plug.Conn.resp(conn, 500, "internal error")
    end)

    url = "http://localhost:#{bypass.port}/api/broken"
    assert {:ok, 500, _body} = MOCK005.SimpleHttpClient.get(url)
  end
end
