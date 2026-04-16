---
id: ETC-MOCK-005
title: "Use Bypass when testing HTTP behavior"
category: mocking
severity: recommendation
summary: >
  Use Bypass to test HTTP-level concerns: status codes, headers, request shape,
  and error conditions. Bypass starts a real local HTTP server so your client
  code runs unchanged, exercising the actual HTTP library behaviour.
principles:
  - boundary-testing
applies_when:
  - "Testing that your HTTP client correctly handles specific status codes (4xx, 5xx)"
  - "Testing that your client sends the expected headers, query params, or body"
  - "Testing retry logic, timeout handling, or connection error behaviour"
  - "Testing that your adapter correctly encodes and decodes requests"
conflicts_with:
  - ETC-MOCK-006
---

# Use Bypass when testing HTTP behavior

Bypass starts a real local HTTP server that your production HTTP client connects
to. Unlike Mox, which replaces the client module entirely, Bypass lets the real
client run — so you test your actual serialisation, header logic, and error
handling, not a mock.

## Problem

When you mock an HTTP client at the module level (e.g., replace `HTTPoison`
with a mock), you only test that your code calls the right mock function with
the right arguments. You don't test that the HTTP request is actually formed
correctly, that your client handles a 429 rate-limit correctly, or that
connection timeouts are handled.

Bypass fills this gap: it's a lightweight Plug-based server you start in the
test, point your HTTP client at, and define responses for. The real HTTP stack
runs end-to-end, which catches serialisation bugs, header-encoding issues, and
client configuration errors.

## Detection

- Tests that mock `HTTPoison.get/2`, `Tesla.get/2`, etc. at the module level
  when the actual concern is how the HTTP response is handled
- No Bypass tests in a codebase that makes HTTP calls to external services
- Tests that assert `HTTPoison.get` was called with specific arguments when
  the test should instead assert on the decoded response

## Bad

```elixir
# Mocks away the HTTP layer entirely — doesn't test real request/response handling
defmodule MyApp.GithubClientTest do
  use ExUnit.Case
  import Mox

  test "fetches user profile" do
    expect(HTTPoisonMock, :get, 1, fn _url, _headers ->
      {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"login": "alice"})}}
    end)
    assert {:ok, %{login: "alice"}} = MyApp.GithubClient.get_user("alice")
  end
end
```

## Good

```elixir
# Bypass runs a real HTTP server — client code is exercised unchanged
defmodule MyApp.GithubClientTest do
  use ExUnit.Case

  setup do
    bypass = Bypass.open()
    %{bypass: bypass}
  end

  test "fetches user profile from real HTTP server", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/users/alice", fn conn ->
      Plug.Conn.resp(conn, 200, ~s({"login": "alice"}))
      |> Plug.Conn.put_resp_header("content-type", "application/json")
    end)

    url = "http://localhost:#{bypass.port}"
    assert {:ok, %{login: "alice"}} = MyApp.GithubClient.get_user("alice", base_url: url)
  end
end
```

## When This Applies

- HTTP adapters that need to handle various status codes
- Clients that must send specific headers (authorization, content-type, accept)
- Retry and backoff logic triggered by 429 or 503 responses
- Webhook consumers that receive HTTP POST bodies

## When This Does Not Apply

- When testing business logic that happens to use HTTP — use Req.Test or Mox instead
- When the HTTP library itself is the thing under test (write a real integration test)
- When the external service has a sandbox environment you can use

## Further Reading

- [Bypass hex.pm](https://hex.pm/packages/bypass)
- [Bypass GitHub — examples](https://github.com/PSPDFKit-labs/bypass)
- [Testing Elixir (Pragmatic) — Chapter on HTTP testing](https://pragprog.com/titles/lmelixir/testing-elixir/)
