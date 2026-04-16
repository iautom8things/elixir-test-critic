# EXPECTED: passes
# BAD PRACTICE: Using a browser-based test tool (like Wallaby) for standard
# LiveView interactions that need no JavaScript. This causes slow, flaky tests
# with no correctness benefit over Phoenix.LiveViewTest.
Mix.install([])

ExUnit.start(autorun: true)

defmodule WallabyOveruseBadTest do
  use ExUnit.Case, async: true

  # Simulate cost metrics for different test approaches
  defmodule TestCost do
    def per_test_ms(:liveview_test), do: 15      # ~15ms typical
    def per_test_ms(:wallaby), do: 800            # ~800ms typical (browser overhead)

    def async_safe?(:liveview_test), do: true
    def async_safe?(:wallaby), do: false          # requires sequential execution

    def requires_browser?(:liveview_test), do: false
    def requires_browser?(:wallaby), do: true     # ChromeDriver/headless browser in CI

    def flaky_risk(:liveview_test), do: :low
    def flaky_risk(:wallaby), do: :medium          # timing-sensitive browser events
  end

  test "bad: using Wallaby for server-rendered form is ~53x slower" do
    liveview_ms = TestCost.per_test_ms(:liveview_test)
    wallaby_ms = TestCost.per_test_ms(:wallaby)

    ratio = div(wallaby_ms, liveview_ms)
    assert ratio >= 50

    # A 200-test suite: LiveViewTest ≈ 3 seconds, Wallaby ≈ 160 seconds
    suite_size = 200
    liveview_total = suite_size * liveview_ms / 1000
    wallaby_total = suite_size * wallaby_ms / 1000

    assert wallaby_total > liveview_total * 10
  end

  test "bad: Wallaby tests cannot run async by default" do
    refute TestCost.async_safe?(:wallaby)
    assert TestCost.async_safe?(:liveview_test)
    # Sequential Wallaby tests compound the slowness
  end

  test "bad: Wallaby requires browser infrastructure that LiveViewTest does not" do
    assert TestCost.requires_browser?(:wallaby)
    refute TestCost.requires_browser?(:liveview_test)
    # ChromeDriver setup in CI, Dockerfile changes, flaky startup
  end

  test "demonstrates: LiveViewTest covers all standard LiveView scenarios" do
    # These interactions need NO browser JS and are fully testable with LiveViewTest:
    covered_by_liveview_test = [
      :form_submit,
      :button_click,
      :event_handling,
      :stream_updates,
      :navigation_patch,
      :navigation_redirect,
      :async_assigns,
      :pubsub_handle_info,
      :component_events,
      :presence_updates
    ]

    assert length(covered_by_liveview_test) == 10

    # Use Wallaby only for:
    actually_needs_wallaby = [
      :third_party_js_widget,
      :custom_js_hook_behaviour,
      :native_browser_api,
      :cross_browser_rendering
    ]

    assert length(actually_needs_wallaby) == 4
  end
end
