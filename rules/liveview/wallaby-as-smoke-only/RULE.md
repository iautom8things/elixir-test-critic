---
id: ETC-LV-008
title: "Reserve Wallaby for JavaScript-dependent smoke tests"
category: liveview
severity: recommendation
summary: >
  Use Phoenix.LiveViewTest (`live/2`, `render_click/1`, etc.) for the vast
  majority of LiveView tests. Reserve Wallaby (browser-based) tests for
  functionality that genuinely requires JavaScript execution: third-party widgets,
  complex drag-and-drop, custom JS hooks, or cross-browser rendering checks.
principles:
  - boundary-testing
applies_when:
  - "Choosing between LiveViewTest and Wallaby for a new LiveView test"
  - "Reviewing a test suite that uses Wallaby for everything"
  - "Testing LiveView interactions that do not depend on JavaScript"
---

# Reserve Wallaby for JavaScript-dependent smoke tests

Phoenix.LiveViewTest drives LiveView entirely in-process, without a browser.
It tests the Elixir-side logic of your LiveView — event handling, assigns,
template rendering, navigation — fast, deterministically, and without external
dependencies. For 90%+ of LiveView test cases this is exactly the right tool.

Wallaby (or any browser-based testing tool) starts a real browser, loads the
page over HTTP and WebSocket, and executes JavaScript. This is the only way to
test functionality that depends on JavaScript:

- Third-party JS widgets (date pickers, maps, rich text editors)
- Custom LiveView JS hooks that manipulate the DOM directly
- File uploads via JavaScript
- Native browser behaviour (clipboard, geolocation, notifications)
- Cross-browser rendering differences

Using Wallaby for ordinary LiveView interactions adds 5-30× more test time,
introduces flakiness from browser startup and network timing, and requires
a headless browser in CI — for no benefit over LiveViewTest.

## Problem

Teams sometimes reach for Wallaby by default because it "tests the whole thing."
In practice, Wallaby tests are:

- Significantly slower (seconds per test vs. milliseconds)
- Harder to debug (async browser events, screenshot archaeology)
- More brittle (timing-sensitive, CI environment-dependent)
- Not necessary for any server-rendered LiveView behaviour

The result is a slow, flaky test suite that developers stop trusting.

## Detection

- Wallaby tests for LiveView interactions that have no custom JS hooks
- Wallaby tests that could be written with `element/2` and `render_click/1`
- A Wallaby test file with >5 tests for a single LiveView that has no JS hooks

## Bad

```elixir
# Using Wallaby for a standard LiveView CRUD form — no JS needed
defmodule MyAppWeb.PostLiveWallabyTest do
  use MyAppWeb.FeatureCase, async: false   # Wallaby is not async-safe by default

  test "creates a post", session do
    session
    |> visit("/posts/new")
    |> fill_in(Query.text_field("Title"), with: "Hello")
    |> click(Query.button("Save"))
    |> assert_text("Post created")
  end
end
```

## Good

```elixir
# LiveViewTest for the same functionality — 10-100× faster
defmodule MyAppWeb.PostLiveTest do
  use MyAppWeb.ConnCase, async: true

  test "creates a post", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/posts/new")

    view |> form("#post-form", post: %{title: "Hello"}) |> render_submit()

    assert render(view) =~ "Post created"
  end
end

# Reserve Wallaby for the JS-dependent parts
defmodule MyAppWeb.RichTextEditorSmokeTest do
  use MyAppWeb.FeatureCase, async: false

  # This genuinely requires browser JS — the rich text editor is a JS widget
  test "formats bold text in the editor", session do
    session
    |> visit("/posts/new")
    |> click(Query.css("[data-testid='bold-button']"))
    |> assert_has(Query.css(".ProseMirror strong"))
  end
end
```

## When This Applies

- Any LiveView test that exercises server-side Elixir logic
- Form submission, event handling, navigation, stream updates

## When This Does Not Apply

- Testing JavaScript-only interactions (client hooks, third-party widgets)
- Smoke tests verifying the full stack works end-to-end in a staging environment
- Cross-browser compatibility checks

## Further Reading

- [Phoenix.LiveViewTest docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html)
- [Wallaby docs](https://hexdocs.pm/wallaby/readme.html)
- [LiveView JS hooks](https://hexdocs.pm/phoenix_live_view/js-interop.html)
