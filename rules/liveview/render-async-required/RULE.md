---
id: ETC-LV-004
title: "Always call render_async for async assigns"
category: liveview
severity: critical
summary: >
  When testing a LiveView that uses `assign_async/3` or `start_async/3`, call
  `render_async(view)` to let the async task complete before asserting on its
  result. Asserting on the HTML before `render_async` only sees the loading state.
principles:
  - assert-not-sleep
does_not_apply_when:
  - "Testing only the loading state before async completes — in that case, assert on the HTML immediately after mount without calling render_async"
applies_when:
  - "Testing a LiveView that uses assign_async/3 or start_async/3"
  - "Asserting on content that is populated by an async operation"
  - "Any LiveView with a loading/error/result pattern for async data"
---

# Always call render_async for async assigns

Phoenix LiveView 0.19+ provides `assign_async/3` and `start_async/3` for
non-blocking data loading. The rendered HTML goes through three states:

1. **Loading**: the async task is running; the LiveView renders a loading indicator
2. **Result** (or **Error**): the task completed; the LiveView renders the data

In LiveViewTest, after mounting the view, async tasks are suspended. You must
call `render_async(view)` to allow the tasks to run and the view to re-render
with the result. Without this call, all assertions see only the loading state.

## Problem

The most common mistake is asserting on the final content immediately after
`live(conn, path)` without calling `render_async`. The assertion fails (content
not found), the developer adds `Process.sleep(50)`, and now the test is both
slow and potentially flaky.

The correct fix is `render_async(view)`, which drives the async task to
completion synchronously within the test process.

## Detection

- `Process.sleep` followed by assertions on content loaded by `assign_async`
- Missing `render_async` calls in tests for LiveViews that use `assign_async`
- `assert render(view) =~ content` immediately after `live/2` when content
  is async-loaded

## Bad

```elixir
test "shows the user's orders", %{conn: conn} do
  user = insert(:user)
  {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/orders")

  # Bad: async task hasn't run yet — this sees the loading state
  assert render(view) =~ "Order #1001"

  # Or bad: sleeping to work around it
  Process.sleep(200)
  assert render(view) =~ "Order #1001"
end
```

## Good

```elixir
test "shows the user's orders", %{conn: conn} do
  user = insert(:user)
  insert(:order, user: user, number: "1001")
  {:ok, view, _html} = live(conn, ~p"/users/#{user.id}/orders")

  # Good: wait for async tasks to complete
  render_async(view)

  assert render(view) =~ "Order #1001"
end
```

## Testing the loading state

```elixir
test "shows a loading indicator while orders are fetched", %{conn: conn} do
  user = insert(:user)
  {:ok, _view, html} = live(conn, ~p"/users/#{user.id}/orders")

  # Assert on initial HTML before async runs — this is valid
  assert html =~ "Loading orders..."
end
```

## When This Applies

- All LiveViews using `assign_async/3` or `start_async/3`
- Any assertion on content that is populated asynchronously

## When This Does Not Apply

- Testing only the loading state before async completes — assert on the initial
  HTML (returned by `live/2`) without calling `render_async`
- LiveViews that do not use any async assigns

## Further Reading

- [Phoenix.LiveViewTest render_async/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#render_async/2)
- [assign_async/3 docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#assign_async/3)
