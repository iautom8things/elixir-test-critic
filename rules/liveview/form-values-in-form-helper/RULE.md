---
id: ETC-LV-003
title: "Pass form values to form/3, not render_submit"
category: liveview
severity: critical
summary: >
  Pass form field values through `element("#form-id", form_data)` or
  `render_submit(element, form_data)` rather than through positional params in
  `render_submit(view, event, params)`. The form helper reads phx-submit from
  the element and correctly encodes form data the way a real browser would.
principles:
  - public-interface
  - boundary-testing
does_not_apply_when:
  - "Testing form submission without any form fields (e.g., a delete confirmation with only a hidden CSRF token)"
applies_when:
  - "Submitting a form with one or more user-editable fields in a LiveView test"
  - "Testing form validation — invalid and valid input paths"
  - "Any test using render_submit, render_change on a form"
---

# Pass form values to form/3, not render_submit

When testing LiveView forms, form data should be passed through the element
selector chain, not as raw params to `render_submit/3`. The difference:

```elixir
# Correct: data flows through the form element
view |> element("#user-form") |> render_submit(%{user: %{name: "Ada"}})

# Also correct: use form/3 helper for typed form data
view |> form("#user-form", user: %{name: "Ada"}) |> render_submit()

# Wrong: data bypasses the form element entirely
render_submit(view, "save", %{user: %{name: "Ada"}})
```

## Problem

`render_submit(view, "save", params)` dispatches the event directly to the
LiveView process without going through the form element. This means:

- The test does not verify that a `<form>` with `phx-submit="save"` exists
- Form-level attributes (`:if` conditionals, `phx-disable-with`, CSRF token
  handling) are not exercised
- Nested field encoding differences between the browser and the test may hide
  key mismatches

The `form/3` helper and element-scoped `render_submit` properly parse the form's
structure and encode data the way a browser would submit it.

## Detection

- `render_submit(view, event_string, params_map)` where the first arg is a view,
  not an element
- `render_change(view, event_string, params_map)` with a view as first argument

## Bad

```elixir
test "creates a user", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/users/new")

  # Bypasses form element — no verification that the form exists or is correct
  render_submit(view, "save", %{user: %{name: "Ada", email: "ada@example.com"}})

  assert render(view) =~ "User created"
end
```

## Good

```elixir
test "creates a user", %{conn: conn} do
  {:ok, view, _html} = live(conn, ~p"/users/new")

  view
  |> form("#user-form", user: %{name: "Ada", email: "ada@example.com"})
  |> render_submit()

  assert render(view) =~ "User created"
end
```

## When This Applies

- All LiveView form submission tests
- All LiveView form change/validation tests

## When This Does Not Apply

- Testing form submission without any form fields (e.g., a delete confirmation
  with only a hidden CSRF token) — in this case `render_click` on the submit
  button is more appropriate
- Testing `handle_event` directly for events that are not tied to a form
  element in the DOM

## Further Reading

- [Phoenix.LiveViewTest form/3](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#form/3)
- [Phoenix.LiveViewTest render_submit/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#render_submit/2)
