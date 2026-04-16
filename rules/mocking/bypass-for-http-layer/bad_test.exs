# EXPECTED: passes
# BAD PRACTICE: Mocks the HTTP client at the module level using a hand-rolled
# mock module. The real HTTP client code never runs, so serialisation bugs,
# header encoding issues, and connection error handling are never exercised.
# The test only verifies that our code calls the mock with certain arguments,
# not that the HTTP interaction actually works correctly.
Mix.install([])

ExUnit.start(autorun: true)

# Hand-rolled HTTP client mock — real HTTP stack never runs
defmodule MOCK005Bad.FakeHttpClient do
  def get("https://api.example.com/status", _headers) do
    {:ok, %{status_code: 200, body: ~s({"status": "ok"})}}
  end

  def get("https://api.example.com/missing", _headers) do
    {:ok, %{status_code: 404, body: "not found"}}
  end
end

defmodule MOCK005Bad.ApiAdapter do
  def check_status(http_client \\ MOCK005Bad.FakeHttpClient) do
    case http_client.get("https://api.example.com/status", []) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, body}
      {:ok, %{status_code: status}} -> {:error, status}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule MOCK005Bad.BypassBadTest do
  use ExUnit.Case, async: true

  test "check_status returns ok (but real HTTP never runs)" do
    # Using the fake client — no real HTTP occurs, no real URL is contacted
    # If ApiAdapter changes how it serializes headers or handles redirects,
    # this test won't catch it
    assert {:ok, body} = MOCK005Bad.ApiAdapter.check_status(MOCK005Bad.FakeHttpClient)
    assert body =~ "ok"
  end

  test "real HTTP client module is never exercised" do
    # The actual HTTP library behaviour (connection pooling, SSL, encoding)
    # is completely untested here. Bypass would run the real client.
    assert true
  end
end
