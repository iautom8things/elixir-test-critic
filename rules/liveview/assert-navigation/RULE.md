---
id: ETC-LV-006
title: "Assert on navigation events explicitly"
category: liveview
severity: warning
summary: >
  Use `assert_patch/2` and `assert_redirect/2` to verify LiveView navigation
  events. Asserting only on rendered content after a navigation event misses
  the URL change and allows wrong routes to go undetected.
principles:
  - public-interface
applies_when:
  - "Testing LiveView actions that call push_patch/2 or push_navigate/2"
  - "Testing LiveView actions that redirect with redirect/2"
  - "Any test where a user interaction is expected to change the URL"
---

# Assert on navigation events explicitly

Phoenix LiveView provides helpers for asserting on navigation:

- `assert_patch(view, path)` — asserts the LiveView patched to `path`
- `assert_patch(view)` — asserts any patch occurred, returns the path
- `assert_redirect(view, path)` — asserts a full redirect to `path`
- `assert_redirect(view)` — asserts any redirect occurred, returns the path

These helpers are the public contract for navigation. Using them instead of
only asserting on rendered content ensures the *URL* itself is correct, not
just the content that happened to appear.

## Problem

When a LiveView action calls `push_patch/2`, two things happen: the URL changes
and the LiveView re-renders. If a test only asserts on the rendered content, it
misses the URL change entirely. A bug that patches to the wrong URL but renders
the same content will pass the test. Conversely, a redirect that accidentally
navigates to the right content but from the wrong route goes undetected.

## Detection

- Tests with `render_click` or `render_submit` followed by `assert render(view) =~`
  but no `assert_patch` or `assert_redirect`
- Test comments saying "after clicking this the URL should change to..."
  but no navigation assertion

## Bad

```elixir
test "saves the post and shows it", %{conn: conn} do
  post = insert(:post)
  {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}/edit")

  view |> form("#post-form", post: %{title: "Updated"}) |> render_submit()

  # Missing: no assertion that the URL changed to /posts/:id
  assert render(view) =~ "Updated"   # passes, but URL might be wrong
end
```

## Good

```elixir
test "saves the post and redirects to show page", %{conn: conn} do
  post = insert(:post)
  {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}/edit")

  view |> form("#post-form", post: %{title: "Updated"}) |> render_submit()

  # Assert the redirect happened to the correct path
  assert_redirect(view, ~p"/posts/#{post.id}")
end

test "filtering patches the URL", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/posts")

  view |> element("#filter-active") |> render_click()

  # Assert the patch updated the URL to include the filter param
  assert_patch(view, ~p"/posts?status=active")
end
```

## When This Applies

- Any LiveView test where an action is expected to call `push_patch/2`,
  `push_navigate/2`, or `redirect/2`
- Filter/search/pagination interactions that update the URL

## When This Does Not Apply

- Testing actions that explicitly should NOT navigate — confirm with
  `refute_redirected` or simply assert the view is still on the same path
- Testing `handle_info` callbacks that update content without navigation

## Further Reading

- [Phoenix.LiveViewTest assert_patch/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#assert_patch/2)
- [Phoenix.LiveViewTest assert_redirect/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#assert_redirect/2)
- [push_patch/2 docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#push_patch/2)
