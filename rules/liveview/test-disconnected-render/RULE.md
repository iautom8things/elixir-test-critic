---
id: ETC-LV-001
title: "Test both disconnected and connected renders"
category: liveview
severity: recommendation
summary: >
  `live(conn, path)` runs the disconnected mount but hands back only the
  connected HTML. When a LiveView renders differently before the WebSocket
  connects, assert on the static HTML with `get(conn, path)` as well.
principles:
  - boundary-testing
applies_when:
  - "The LiveView branches on `connected?(socket)` in mount or render"
  - "The static HTML matters on its own: crawlers, link previews, meta tags, users without JavaScript"
does_not_apply_when:
  - "The LiveView renders the same content connected and disconnected"
  - "The test targets an interaction that only exists once connected"
---

# Test both disconnected and connected renders

A Phoenix LiveView goes through two render phases:

1. **Disconnected** (HTTP GET): the server renders a static HTML page. This is
   what search engines, link previewers, and users with slow connections see.
2. **Connected** (WebSocket): the client upgrades and the LiveView re-mounts
   with a live socket. This is the interactive state.

`live(conn, path)` goes through both. It issues the HTTP GET first, then
connects. A `mount/3` that crashes during the GET fails the test, so `live/2`
alone already covers "does the disconnected mount run".

## Problem

What `live/2` does not give you is the disconnected HTML. The `html` it returns
is the connected render. If the view shows something different before it
connects, such as a placeholder, a skeleton, or content gated on
`connected?(socket)`, no assertion sees it. A wrong page title, missing meta
tags, or an empty body for crawlers passes unnoticed.

## Detection

- A LiveView that calls `connected?(socket)`, with no test asserting on
  `html_response/2` for its route
- A route whose static HTML matters (public, indexed, shared as a link), tested
  only through `live/2`

Do not flag a test only because it calls `live/2` without a `get/2`. Check the
LiveView first.

## Bad

```elixir
defmodule MyAppWeb.PostLiveTest do
  use MyAppWeb.ConnCase, async: true

  test "renders the post", %{conn: conn} do
    post = insert(:post, title: "Hello")

    # Runs the disconnected mount, but `html` is the connected render.
    # If the static page shows a placeholder until connected, nothing checks it.
    {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")

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

- LiveViews whose mount or render branches on `connected?(socket)`
- Public pages where the static HTML is what crawlers and link previews read

## When This Does Not Apply

- LiveViews that render the same content in both phases. `live/2` already runs
  the disconnected mount, so a separate `get/2` adds nothing.
- LiveViews that redirect immediately on mount — the disconnected render is empty
- LiveViews embedded inside another LiveView (not directly routable)
- Testing a specific interaction that only occurs in the connected state — add
  the disconnected test separately rather than forcing every test to do both

## Further Reading

- [Phoenix.LiveViewTest docs — live/2 and get/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html)
- [LiveView lifecycle — connected? check](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#connected?/1)
