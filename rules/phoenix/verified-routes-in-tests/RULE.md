---
id: ETC-PHX-002
title: "Use verified routes (~p) in tests"
category: phoenix
severity: recommendation
summary: >
  Use the `~p` sigil for URL construction in tests instead of string literals.
  Verified routes are checked at compile time against your router, so route renames
  or removals surface as compile errors rather than silent test failures.
principles:
  - boundary-testing
applies_when:
  - "Constructing URLs in ConnCase or LiveViewTest tests"
  - "Any test that calls get/post/put/delete/patch with a URL"
  - "Any test that calls live/2 with a path"
---

# Use verified routes (~p) in tests

Phoenix 1.7+ provides the `~p` sigil for route verification. Use it in tests
the same way you use it in application code. Verified routes are validated
against `MyAppWeb.Router` at compile time — a removed or renamed route becomes
a compile error rather than a test that silently returns 404 and passes for
the wrong reason.

## Problem

Hardcoded string paths like `"/users/1"` or `"/admin/posts"` in tests become
stale the moment the route changes. They compile and run but may now match a
different route — or no route at all — leading to false passes or confusing
failures. The connection between the test and the actual route the application
defines is entirely implicit and invisible to the compiler.

## Detection

- `get(conn, "/...")`  where the path is a string literal
- `live(conn, "/...")` where the path is a string literal
- `assert redirected_to(conn) == "/..."` with a hardcoded string

## Bad

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase, async: true

  test "shows a user", %{conn: conn} do
    user = insert(:user)
    conn = get(conn, "/users/#{user.id}")   # hardcoded path — not verified

    assert html_response(conn, 200) =~ user.name
  end

  test "redirects to login", %{conn: conn} do
    conn = get(conn, "/dashboard")

    assert redirected_to(conn) == "/login"  # hardcoded — will not catch renames
  end
end
```

## Good

```elixir
defmodule MyAppWeb.UserControllerTest do
  use MyAppWeb.ConnCase, async: true

  test "shows a user", %{conn: conn} do
    user = insert(:user)
    conn = get(conn, ~p"/users/#{user.id}")   # verified at compile time

    assert html_response(conn, 200) =~ user.name
  end

  test "redirects to login", %{conn: conn} do
    conn = get(conn, ~p"/dashboard")

    assert redirected_to(conn) == ~p"/login"  # both sides verified
  end
end
```

## When This Applies

- All Phoenix controller tests
- All LiveView tests using `live/2`
- Any assertion on redirect locations

## When This Does Not Apply

- Testing external URLs or third-party redirects — those are not in your router
- Tests that deliberately use invalid paths to assert 404 behaviour

## Further Reading

- [Phoenix Verified Routes guide](https://hexdocs.pm/phoenix/verified_routes.html)
- [Phoenix.VerifiedRoutes docs](https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html)
