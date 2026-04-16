# EXPECTED: passes
# BAD PRACTICE: Asserting only on rendered content after a navigation event.
# The URL change is never verified. A bug that navigates to the wrong route
# but renders the same content will pass these tests undetected.
Mix.install([])

ExUnit.start(autorun: true)

defmodule MissingNavigationAssertionBadTest do
  use ExUnit.Case, async: true

  defmodule FakeView do
    # Simulates a LiveView that redirected to the wrong path but rendered the right content
    def current_render, do: "Post was saved successfully"
    def actual_path, do: "/posts/wrong-path"   # bug: wrong redirect target
    def expected_path, do: "/posts/42"
  end

  test "bad: asserts only on content, misses wrong redirect destination" do
    # In a real test:
    #   view |> form("#post-form", post: %{title: "Updated"}) |> render_submit()
    #   assert render(view) =~ "Post was saved successfully"
    #
    # This passes! But the LiveView redirected to /posts/wrong-path instead of /posts/42.
    # The content happened to match, but the URL is wrong.

    content = FakeView.current_render()
    assert content =~ "Post was saved successfully"

    # The bug is invisible because we never checked the path
    assert FakeView.actual_path() != FakeView.expected_path()
  end

  test "bad: no assert_patch after filter interaction" do
    # After clicking a filter, we assert the content changed but not the URL
    filtered_content = "Showing: active posts"

    assert filtered_content =~ "active posts"

    # Missing: assert_patch(view, ~p"/posts?status=active")
    # The URL might not have been patched at all — the filter might work via
    # assigns only, with no URL update. We'd never know.
    assert true
  end

  test "demonstrates: explicit navigation assertion catches the wrong-route bug" do
    actual_path = FakeView.actual_path()
    expected_path = FakeView.expected_path()

    # assert_redirect(view, expected_path) would catch this:
    assert actual_path != expected_path, "This bug would be caught by assert_redirect"
  end
end
