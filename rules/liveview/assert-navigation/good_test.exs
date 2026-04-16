# EXPECTED: passes
Mix.install([])

# Demonstrates: explicit navigation assertions vs. asserting only on rendered content.
#
# In a real Phoenix LiveView test:
#
#   test "saves post and redirects to show page", %{conn: conn} do
#     post = insert(:post)
#     {:ok, view, _html} = live(conn, ~p"/posts/#{post.id}/edit")
#
#     view |> form("#post-form", post: %{title: "Updated"}) |> render_submit()
#
#     # assert_redirect verifies BOTH the navigation type and the destination URL
#     assert_redirect(view, ~p"/posts/#{post.id}")
#   end
#
#   test "filter patches the URL", %{conn: conn} do
#     {:ok, view, _html} = live(conn, ~p"/posts")
#
#     view |> element("#filter-active") |> render_click()
#
#     # assert_patch verifies the URL was updated with the filter param
#     assert_patch(view, ~p"/posts?status=active")
#   end
#
# Navigation assertions verify the URL, not just the content.
# Content might look right even if the route is wrong.

ExUnit.start(autorun: true)

defmodule AssertNavigationGoodTest do
  use ExUnit.Case, async: true

  # Simulate navigation state tracking
  defmodule NavigationTracker do
    def new(initial_path), do: %{path: initial_path, patches: [], redirects: []}

    def patch(tracker, path),
      do: %{tracker | path: path, patches: [path | tracker.patches]}

    def redirect(tracker, path),
      do: %{tracker | path: path, redirects: [path | tracker.redirects]}

    def assert_patch(%{patches: [last | _]}, expected_path),
      do: assert(last == expected_path)

    def assert_redirect(%{redirects: [last | _]}, expected_path),
      do: assert(last == expected_path)
  end

  test "assert_patch verifies URL changed to the expected path" do
    nav = NavigationTracker.new("/posts")

    # Simulate user clicking a filter — LiveView calls push_patch
    nav = NavigationTracker.patch(nav, "/posts?status=active")

    # Assert both the navigation type and the destination
    NavigationTracker.assert_patch(nav, "/posts?status=active")
    assert nav.path == "/posts?status=active"
  end

  test "assert_redirect verifies full navigation after form submit" do
    post_id = 42
    nav = NavigationTracker.new("/posts/#{post_id}/edit")

    # Simulate form submit — LiveView calls redirect(conn, to: ~p"/posts/:id")
    nav = NavigationTracker.redirect(nav, "/posts/#{post_id}")

    NavigationTracker.assert_redirect(nav, "/posts/#{post_id}")
    assert nav.path == "/posts/#{post_id}"
  end

  test "pagination patches with correct page param" do
    nav = NavigationTracker.new("/posts")

    nav = NavigationTracker.patch(nav, "/posts?page=2")

    NavigationTracker.assert_patch(nav, "/posts?page=2")
  end
end
