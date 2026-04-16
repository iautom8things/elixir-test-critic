---
id: ETC-LV-002
title: "Use element-scoped events, not direct events"
category: liveview
severity: warning
summary: >
  Prefer `view |> element("#selector") |> render_click()` over
  `render_click(view, "event-name", params)`. Element-scoped events target a
  specific DOM element, matching how a real user interacts with the page, and
  catch mismatches between event names and the elements that fire them.
principles:
  - public-interface
applies_when:
  - "Triggering click, change, submit, or other events in LiveView tests"
  - "Any test using Phoenix.LiveViewTest event helpers"
---

# Use element-scoped events, not direct events

Phoenix.LiveViewTest provides two ways to fire events:

- **Direct**: `render_click(view, "event-name", params)` — bypasses the DOM,
  fires the named event directly on the LiveView process.
- **Element-scoped**: `view |> element("#btn") |> render_click()` — finds the
  element, reads its `phx-click` attribute, and fires that event with any
  embedded params from the element.

Element-scoped events are the right default. They test the full path from DOM
element to event handler, not just the handler in isolation.

## Problem

`render_click(view, "delete", %{id: 1})` will succeed even if there is no button
on the page with `phx-click="delete"`. The event is dispatched directly to the
LiveView process, skipping the DOM entirely. This means:

- The test passes even if the button was removed from the template
- The test passes even if the event name has a typo in the template
- Params hardcoded in the test may diverge from the `phx-value-*` attributes
  actually present in the HTML

## Detection

- `render_click(view, event_name, params)` with a non-element first call
- `render_submit(view, event_name, params)` without going through `element/2`
- `render_change(view, event_name, params)` without going through `element/2`

## Bad

```elixir
test "deletes the post", %{conn: conn} do
  post = insert(:post)
  {:ok, view, _html} = live(conn, ~p"/posts")

  # Fires the event directly — doesn't verify a delete button exists in the DOM
  render_click(view, "delete", %{id: to_string(post.id)})

  refute render(view) =~ post.title
end
```

## Good

```elixir
test "deletes the post", %{conn: conn} do
  post = insert(:post)
  {:ok, view, _html} = live(conn, ~p"/posts")

  # Finds the actual DOM element and fires its phx-click event
  view
  |> element("[data-role='delete-post'][data-id='#{post.id}']")
  |> render_click()

  refute render(view) =~ post.title
end
```

## When This Applies

- All LiveView event tests: click, change, submit, keydown, etc.
- Tests where there is a clear DOM element responsible for the event

## When This Does Not Apply

- Testing `handle_info/2` — messages arrive from external processes, not DOM
  events; send them with `send(view.pid, message)`
- Testing events fired from JavaScript hooks where there is no `phx-*` attribute
  to target — in that case `render_click(view, event, params)` is acceptable
  with a comment explaining why

## Further Reading

- [Phoenix.LiveViewTest — element/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#element/2)
- [Phoenix.LiveViewTest — render_click/1](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#render_click/1)
