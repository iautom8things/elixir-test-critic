---
id: ETC-LV-007
title: "Assert stream content via DOM, not assigns"
category: liveview
severity: warning
summary: >
  When testing LiveView streams, assert on the rendered HTML rather than on
  `socket.assigns.streams`. Stream items are pruned from server memory after
  being sent to the client — the assigns do not reflect what the DOM contains.
principles:
  - public-interface
applies_when:
  - "Testing any LiveView that uses stream/4 or stream_insert/4"
  - "Asserting that a list of items is displayed in a stream-backed LiveView"
  - "Testing stream operations: insert, delete, reset"
---

# Assert stream content via DOM, not assigns

LiveView streams (`stream/4`, `stream_insert/4`, `stream_delete/3`) are a
client-side data structure. The server sends DOM patches to insert, update,
or delete items, and the items are then pruned from `socket.assigns`. Asserting
on `assigns.streams.items` after initial load will show an empty or stale list —
not what the client DOM contains.

The correct approach: assert on `render(view)` or use `has_element?/2` to check
that specific items appear in the rendered HTML.

## Problem

A developer testing a stream-backed list might write:

```elixir
assert length(view.assigns.streams.posts.inserts) == 3
```

This assertion reflects what was *sent* in the last diff, not what is in the
DOM. After `stream_insert/3` sends an item, it is removed from the server's
stream buffer. The DOM has the item; the assigns do not.

## Detection

- Assertions reading `socket.assigns.streams.*`
- Assertions on `view.assigns` for stream-backed collections
- `assert length(assigns.streams.items.inserts) == n` patterns

## Bad

```elixir
test "displays all posts in the stream", %{conn: conn} do
  insert_list(3, :post)
  {:ok, view, _html} = live(conn, ~p"/posts")

  # Bad: streams are pruned from assigns — this may be empty or incomplete
  assert length(view.assigns.streams.posts.inserts) == 3
end
```

## Good

```elixir
test "displays all posts in the stream", %{conn: conn} do
  posts = insert_list(3, :post)
  {:ok, view, html} = live(conn, ~p"/posts")

  # Good: assert on what the client DOM actually contains
  for post <- posts do
    assert html =~ post.title
  end

  # Or use has_element? for structural checks
  assert has_element?(view, "[data-role='post-item']")
end

test "removes a post from the stream", %{conn: conn} do
  post = insert(:post, title: "To Be Deleted")
  {:ok, view, _html} = live(conn, ~p"/posts")

  view |> element("[data-role='delete'][data-id='#{post.id}']") |> render_click()

  # Assert the DOM no longer contains the deleted item
  refute has_element?(view, "#post-#{post.id}")
  refute render(view) =~ "To Be Deleted"
end
```

## When This Applies

- All tests for LiveViews using `stream/4`
- Tests for insert, delete, and reset stream operations

## When This Does Not Apply

- Testing the stream configuration or initial setup in isolation (unit testing
  the mount function directly)
- Testing that `stream_insert/3` was called with specific arguments via Mox
  (though this couples to implementation detail)

## Further Reading

- [Phoenix.LiveView stream/4 docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#stream/4)
- [Phoenix.LiveViewTest has_element?/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#has_element?/2)
- [Streams overview — Phoenix LiveView guides](https://hexdocs.pm/phoenix_live_view/streams.html)
