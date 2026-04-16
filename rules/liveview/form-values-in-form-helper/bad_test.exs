# EXPECTED: passes
# BAD PRACTICE: Submitting form data directly to the view rather than through
# a form element. The test bypasses DOM verification and can pass even when
# the form element has a wrong event name or doesn't exist at all.
Mix.install([])

ExUnit.start(autorun: true)

defmodule DirectFormSubmitBadTest do
  use ExUnit.Case, async: true

  # Simulate direct render_submit(view, event, params) — no DOM lookup
  defp render_submit_direct(_view, event, params) do
    # In real LiveViewTest: render_submit(view, "save", %{user: %{name: "Ada"}})
    # Fires the event on the LiveView process directly. No form element found.
    {:ok, "#{event} submitted with #{inspect(params)}"}
  end

  defp current_html do
    # The form was renamed: phx-submit changed from "save" to "create-user"
    # The test still passes because it dispatches directly to the handler.
    ~s(<form id="user-form" phx-submit="create-user"><input name="name"/></form>)
  end

  test "bad: direct submit succeeds even when form phx-submit was renamed" do
    html = current_html()

    # The form has phx-submit="create-user" but we submit "save"
    result = render_submit_direct(nil, "save", %{user: %{name: "Ada"}})

    # Test passes! But in a real app, a user clicking the submit button
    # would fire "create-user", not "save". The test is testing the wrong event.
    assert {:ok, _} = result
    assert html =~ ~s(phx-submit="create-user")
    refute html =~ ~s(phx-submit="save")  # mismatch is invisible to the test
  end

  test "bad: test passes even when the form element was removed from the template" do
    # The form was removed during a refactor but handle_event("save", ...) still exists.
    empty_html = "<p>Form was moved to a component</p>"

    result = render_submit_direct(nil, "save", %{user: %{name: "Ada"}})

    # Test passes! No form in the HTML, but direct dispatch doesn't check.
    assert {:ok, _} = result
    refute empty_html =~ "phx-submit"  # no form exists, test is vacuous
  end

  test "bad: hardcoded params may not match actual phx-value-* encoding" do
    # Browser encodes phx-value-user-name="Ada" as %{"user-name" => "Ada"}
    # but direct dispatch uses %{user: %{name: "Ada"}} — different key structure.
    # No error is raised; the LiveView just receives unexpected params silently.
    result = render_submit_direct(nil, "save", %{user: %{name: "Ada"}})
    assert {:ok, _} = result
  end
end
