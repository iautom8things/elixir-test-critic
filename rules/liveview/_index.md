---
category: liveview
title: "LiveView"
description: >
  Rules for testing Phoenix LiveView applications using Phoenix.LiveViewTest.
  These rules cover the full LiveView lifecycle: disconnected render, connected
  interaction, async assigns, streams, forms, navigation, and tool selection.
rules:
  - test-disconnected-render
  - element-scoped-events
  - form-values-in-form-helper
  - render-async-required
  - resilient-selectors
  - assert-navigation
  - stream-dom-assertions
  - wallaby-as-smoke-only
---

# LiveView Testing Rules

This category covers testing patterns specific to Phoenix LiveView using
`Phoenix.LiveViewTest`. LiveView has a rich set of test helpers that, when
used correctly, produce a fast, deterministic, and comprehensive test suite.

## Core Themes

**Test both render phases.** Every routable LiveView goes through a disconnected
(HTTP GET) render and a connected (WebSocket) render. Both phases can have bugs.
Use `get(conn, path)` for the first and `live(conn, path)` for the second.

**Target DOM elements, not event strings.** The `element/2` + `render_click/1`
pipeline verifies that the element exists, reads its event name from the HTML,
and fires it. Direct `render_click(view, "event")` skips DOM verification.

**Pass form data through the form.** The `form/3` helper and element-scoped
`render_submit` correctly encode form data and verify the form element exists.
Passing raw params directly to `render_submit(view, event, params)` bypasses
the form entirely.

**Async assigns need `render_async`.** After mounting a LiveView with async
assigns, call `render_async(view)` before asserting on the loaded content.
`Process.sleep` does not advance async tasks in LiveViewTest.

**Stable selectors outlive styling changes.** Use `#id` and `[data-role="..."]`
selectors instead of CSS classes. CSS classes are styling details; IDs and data
attributes are semantic identifiers.

**Assert navigation explicitly.** `assert_patch/2` and `assert_redirect/2`
verify the URL, not just the content. A bug that navigates to the wrong route
but renders the same content is only caught by navigation assertions.

**Streams live in the DOM, not assigns.** Stream items are pruned from server
memory after being sent to the client. Assert on `render(view)` and
`has_element?/2`, not on `socket.assigns.streams`.

**LiveViewTest first, Wallaby last.** LiveViewTest covers all server-side
LiveView behaviour — fast, async, and without a browser. Reserve Wallaby for
functionality that genuinely requires JavaScript execution.

## Rules

| ID | Rule | Severity |
|----|------|----------|
| ETC-LV-001 | [Test both disconnected and connected renders](test-disconnected-render/) | warning |
| ETC-LV-002 | [Use element-scoped events, not direct events](element-scoped-events/) | warning |
| ETC-LV-003 | [Pass form values to form/3, not render_submit](form-values-in-form-helper/) | critical |
| ETC-LV-004 | [Always call render_async for async assigns](render-async-required/) | critical |
| ETC-LV-005 | [Use IDs and data attributes, not CSS classes](resilient-selectors/) | recommendation |
| ETC-LV-006 | [Assert on navigation events explicitly](assert-navigation/) | warning |
| ETC-LV-007 | [Assert stream content via DOM, not assigns](stream-dom-assertions/) | warning |
| ETC-LV-008 | [Reserve Wallaby for JavaScript-dependent smoke tests](wallaby-as-smoke-only/) | recommendation |
