---
id: ETC-LV-001
title: "Test both disconnected and connected renders"
category: liveview
severity: warning
summary: >
  Use `get(conn, path)` to verify the static (disconnected) HTML and then
  `live(conn, path)` to test the connected LiveView. Testing only the connected
  state misses the initial static render that users and crawlers see.
principles:
  - boundary-testing
applies_when:
  - "Testing any LiveView that is rendered server-side before the WebSocket connects"
  - "LiveViews exposed to crawlers, SEO, or users with JavaScript disabled"
  - "Any LiveView mounted via a router `live` macro"
---

# Test both disconnected and connected renders

A Phoenix LiveView goes through two render phases:

1. **Disconnected** (HTTP GET): the server renders a static HTML page. This is
   what search engines, link previewers, and users with slow connections see.
2. **Connected** (WebSocket): the client upgrades and the LiveView re-mounts
   with a live socket. This is the interactive state.

Testing only the connected state leaves the disconnected render — and any error
that exists only in that path — completely uncovered.

## Problem

`live(conn, path)` exercises only the WebSocket-connected mount. If `mount/3`
crashes during the HTTP GET (before the WebSocket upgrade), `live/2` will not
catch it. Conversely, some assigns are set differently in disconnected mode
(`connected?(socket)` returns `false`), so bugs in that branch are invisible to
pure LiveView tests.

## Detection

- Test files that `live/2` without a preceding `get/2` on the same path
- Test modules with no assertions using `html_response/2` for LiveView routes

## Bad

```elixir
defmodule MyAppWeb.PostLiveTest do
  use MyAppWeb.ConnCase, async: true

  test "renders the post", %{conn: conn} do
    post = insert(:post, title: "Hello")

    # Skips the disconnected render entirely
    {:ok, view, html} = live(conn, ~p"/posts/#{post.id}")

    assert html =~ "Hello"
  end
end
```

## Good

```elixir
defmodule MyAppWeb.PostLiveTest do
  use MyAppWeb.ConnCase, async: true

  test "renders disconnected and connected", %{conn: conn} do
    post = insert(:post, title: "Hello")

    # 1. Test the disconnected (static HTTP) render
    conn = get(conn, ~p"/posts/#{post.id}")
    assert html_response(conn, 200) =~ "Hello"

    # 2. Test the connected (WebSocket) render
    {:ok, view, _html} = live(conn)
    assert render(view) =~ "Hello"
  end
end
```

## When This Applies

- All LiveViews mounted via the router
- Any LiveView that has meaningful content in the initial render

## When This Does Not Apply

- LiveViews that redirect immediately on mount — the disconnected render is empty
- LiveViews embedded inside another LiveView (not directly routable)
- Testing a specific interaction that only occurs in the connected state — add
  the disconnected test separately rather than forcing every test to do both

## Further Reading

- [Phoenix.LiveViewTest docs — live/2 and get/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html)
- [LiveView lifecycle — connected? check](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#connected?/1)
