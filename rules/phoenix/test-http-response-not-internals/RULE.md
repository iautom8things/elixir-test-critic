---
id: ETC-PHX-001
title: "Test HTTP responses, not controller internals"
category: phoenix
severity: warning
summary: >
  Assert on HTTP status codes, response bodies, headers, and redirects — not on
  conn.assigns, internal module calls, or controller-private state. The HTTP
  response is the public contract; everything else is an implementation detail.
principles:
  - public-interface
  - boundary-testing
applies_when:
  - "Writing Phoenix controller tests using ConnCase"
  - "Testing any action that returns a rendered response or redirect"
  - "Testing JSON API endpoints"
related_rules:
  - ETC-ABS-002
---

# Test HTTP responses, not controller internals

A Phoenix controller is an HTTP boundary. Its public contract is: given this
request, produce this response. Tests should verify that contract — status code,
response body, redirect location, headers — not how the controller achieved it.

## Problem

When tests assert on `conn.assigns`, call controller functions directly, or
check which internal functions were invoked, they couple tests to implementation
details. A refactor that produces the same HTTP response — perhaps by inlining a
helper or changing an assign name — will break these tests for no user-visible
reason.

The canonical mistake is asserting `conn.assigns.user == expected_user` instead
of asserting that the response body contains the user's name, or that the status
is 200 and the JSON payload has the right shape.

## Detection

- Assertions reading `conn.assigns.something`
- Direct calls to controller module functions (not through `get/post/etc.`)
- Assertions on `conn.private` fields that are not part of the HTTP contract
- `assert called MyApp.SomeService.do_thing()` style assertions in controller tests

## Bad

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase, async: true

  test "shows a user", %{conn: conn} do
    user = insert(:user, name: "Ada")
    conn = get(conn, ~p"/users/#{user.id}")

    # Bad: asserting on conn.assigns — implementation detail
    assert conn.assigns.user.name == "Ada"
    assert conn.assigns.page_title == "Ada's Profile"
  end
end
```

## Good

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase, async: true

  test "shows a user's profile page", %{conn: conn} do
    user = insert(:user, name: "Ada")
    conn = get(conn, ~p"/users/#{user.id}")

    assert html_response(conn, 200) =~ "Ada"
  end

  test "redirects unauthenticated requests", %{conn: conn} do
    conn = get(conn, ~p"/users/1")

    assert redirected_to(conn) == ~p"/login"
  end

  test "returns user JSON", %{conn: conn} do
    user = insert(:user, name: "Ada")
    conn = get(conn, ~p"/api/users/#{user.id}")

    assert %{"name" => "Ada"} = json_response(conn, 200)
  end
end
```

## When This Applies

- All Phoenix controller tests
- All plug pipeline tests
- API endpoint tests

## When This Does Not Apply

- Plug unit tests that explicitly test what a plug puts in `conn` — that is the
  plug's public contract
- Tests for `conn` transformations in custom plugs where the assign IS the output

## Further Reading

- [Phoenix.ConnTest docs](https://hexdocs.pm/phoenix/Phoenix.ConnTest.html)
- [Testing Phoenix Controllers — Phoenix guides](https://hexdocs.pm/phoenix/testing_controllers.html)
