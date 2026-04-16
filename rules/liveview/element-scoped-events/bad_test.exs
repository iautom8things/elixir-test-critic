# EXPECTED: passes
# BAD PRACTICE: Firing events directly on the view rather than through element/2.
# This bypasses DOM verification — the test passes even if the button doesn't
# exist in the template, or if the phx-click attribute uses a different name.
Mix.install([])

ExUnit.start(autorun: true)

defmodule DirectEventDispatchBadTest do
  use ExUnit.Case, async: true

  # Simulate direct event dispatch (no DOM lookup)
  defp render_click_direct(_view, event, params) do
    # In real LiveViewTest: render_click(view, "delete", %{id: "42"})
    # This fires the event on the LiveView process without verifying any element exists.
    {:ok, "#{event} fired with #{inspect(params)}"}
  end

  # Simulate what the template actually renders
  defp current_html do
    # Note: the button was renamed from phx-click="delete" to phx-click="remove"
    # but the test still uses "delete" — direct dispatch hides this mismatch.
    ~s(<button id="remove-btn" phx-click="remove" phx-value-id="42">Remove</button>)
  end

  test "bad: direct dispatch succeeds even when the event name mismatches the template" do
    html = current_html()

    # The template has phx-click="remove", but we dispatch "delete".
    # In a real LiveViewTest, render_click(view, "delete", ...) would succeed
    # if the LiveView has a handle_event("delete", ...) clause — regardless of
    # whether any element with phx-click="delete" exists in the HTML.
    result = render_click_direct(nil, "delete", %{id: "42"})
    assert {:ok, _} = result

    # The test passes, but the rendered HTML has no phx-click="delete" element.
    refute html =~ ~s(phx-click="delete")
    assert html =~ ~s(phx-click="remove")  # the real event name
    # A user clicking the button would fire "remove", not "delete" — test is wrong.
  end

  test "bad: hardcoded params may diverge from phx-value-* in the template" do
    # Direct dispatch: we hardcode %{id: "42"}
    result = render_click_direct(nil, "delete", %{id: "42"})
    assert {:ok, _} = result

    # But the template might have phx-value-post-id="42" which becomes %{"post-id" => "42"}
    # — a different key. Element-scoped dispatch picks up the actual phx-value-* attrs.
    # Direct dispatch silently uses whatever we hardcode.
    assert true
  end
end
