---
id: ETC-LV-005
title: "Use IDs and data attributes, not CSS classes"
category: liveview
severity: recommendation
summary: >
  Select LiveView elements in tests using `#element-id` or `[data-role="..."]`
  attributes rather than CSS class selectors like `.btn-primary`. IDs and data
  attributes are stable semantic identifiers; CSS classes are styling details
  that change frequently.
principles:
  - public-interface
applies_when:
  - "Using element/2 in LiveView tests to select DOM elements"
  - "Any test that targets a specific button, form, or interactive element"
---

# Use IDs and data attributes, not CSS classes

Element selectors in LiveViewTest act like CSS selectors. The choice of selector
determines how fragile your tests are:

| Selector type | Stability | Couples test to |
|---------------|-----------|-----------------|
| `#element-id` | High | Element identity |
| `[data-role="delete"]` | High | Semantic purpose |
| `.btn-primary` | Low | Visual style |
| `button` | Low | DOM structure |

CSS classes communicate *appearance*. A designer renaming `.btn-primary` to
`.button--primary` or swapping to Tailwind classes will break tests that use
class selectors — none of the user-visible behaviour changed.

IDs and `data-*` attributes communicate *identity* and *role*, which are the
properties tests should care about.

## Problem

CSS class selectors create invisible coupling between the test suite and the
CSS framework or design system. Any refactor of the styling layer breaks tests
even when the application logic is unchanged. This erodes confidence in the
test suite and creates friction for UI changes.

## Detection

- `element(view, ".css-class")` — dot-prefixed selector
- `element(view, "button.btn")` — element with CSS class qualifier
- `element(view, "div > span.label")` — structural DOM path with classes

## Bad

```elixir
test "deletes the post", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/posts")

  # Brittle: breaks if the CSS class changes or Tailwind replaces it
  view |> element("button.btn-danger") |> render_click()

  refute render(view) =~ "My Post"
end
```

## Good

```elixir
test "deletes the post", %{conn: conn} do
  post = insert(:post)
  {:ok, view, _html} = live(conn, ~p"/posts")

  # Stable: data-role is a semantic attribute — survives styling changes
  view |> element("[data-role='delete-post'][data-id='#{post.id}']") |> render_click()

  refute render(view) =~ post.title
end
```

## When This Applies

- All `element/2` selector calls in LiveView tests
- Any `assert has_element?(view, selector)` assertion

## When This Does Not Apply

- Testing that a CSS class IS present (e.g., verifying an active/error state is
  styled correctly) — in this case the class is the thing being tested
- End-to-end or visual regression tests where styling IS the subject

## Further Reading

- [Phoenix.LiveViewTest element/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#element/2)
- [Testing data attributes — MDN](https://developer.mozilla.org/en-US/docs/Learn/HTML/Howto/Use_data_attributes)
