---
id: ETC-MOCK-006
title: "Use Req.Test for business logic over HTTP"
category: mocking
severity: recommendation
summary: >
  When using the Req HTTP library, use Req.Test to stub responses for business
  logic tests. Req.Test plugs a stub adapter into the Req stack without starting
  a real HTTP server, keeping tests fast while still exercising your response
  parsing logic.
principles:
  - boundary-testing
  - purity-separation
applies_when:
  - "Your codebase uses the Req HTTP library"
  - "You want to test how your code handles specific API responses"
  - "You need to test response parsing, error handling, or retry logic built into Req"
conflicts_with:
  - ETC-MOCK-005
---

# Use Req.Test for business logic over HTTP

`Req.Test` is a built-in testing companion for the Req HTTP library. It lets
you stub HTTP responses without starting a real server (unlike Bypass) and
without replacing your HTTP module with a mock (unlike Mox). It's the right
tool when you're testing business logic that uses Req under the hood.

## Problem

Req's plugin architecture makes it possible to intercept requests at the Req
level and return stub responses. Using Mox to replace the entire HTTP module
when you're already using Req throws away Req's middleware pipeline — your
response decoding, retry logic, and header normalization are all bypassed.

Bypass, on the other hand, is fine but requires starting a local HTTP server
and pointing your client at a custom port. For pure business-logic tests,
`Req.Test` is simpler and faster.

## Detection

- Codebases that use Req but mock HTTP with Mox or hand-rolled modules
- Tests that start Bypass servers to test Req-based business logic
  (Bypass is better for testing the HTTP layer itself)

## Bad

```elixir
# Using a hand-rolled fake instead of Req.Test
defmodule MyApp.WeatherTest do
  test "fetches temperature" do
    # Bypasses Req entirely — none of Req's decoding/retry logic runs
    fake_response = %{"temperature" => 22}
    assert MyApp.Weather.get_temp("London", fake_response) == 22
  end
end
```

## Good

```elixir
defmodule MyApp.WeatherTest do
  use ExUnit.Case, async: true

  test "fetches temperature from API" do
    # Req.Test stubs the response inside Req's stack
    Req.Test.stub(MyApp.Weather, fn conn ->
      Req.Test.json(conn, %{"temperature" => 22, "city" => "London"})
    end)

    # Real Req request processing runs — JSON decoding, middleware, etc.
    assert {:ok, 22} = MyApp.Weather.get_temp("London")
  end
end
```

## When This Applies

- Applications using the `Req` library for HTTP
- Testing response parsing, error classification, or retry conditions
- Tests that want Req's full middleware pipeline to run

## When This Does Not Apply

- Applications using Tesla, HTTPoison, Finch, or other HTTP libraries
  (use Bypass or Mox with a behaviour instead)
- When testing actual HTTP protocol behaviour (headers, status handling)
  — use Bypass for that

## Further Reading

- [Req.Test hexdocs](https://hexdocs.pm/req/Req.Test.html)
- [Req GitHub — testing guide](https://github.com/wojtekmach/req)
- [Req.Test — stub/2 and json/2](https://hexdocs.pm/req/Req.Test.html#stub/2)
