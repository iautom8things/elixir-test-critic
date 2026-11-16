# EXPECTED: passes
# BAD PRACTICE: Asserting only on the connected LiveView render when the view
# renders something different before it connects. live/2 does run the
# disconnected mount, so a crash there would fail the test. What goes unchecked
# is the static HTML itself: this view ships a page with no title to crawlers.
Mix.install([])

ExUnit.start(autorun: true)

defmodule ConnectedOnlyRenderTest do
  use ExUnit.Case, async: true

  # Stands in for the HTML live/2 returns: the connected render.
  defp connected_render(post) do
    "<h1>#{post.title}</h1><p>#{post.body}</p>"
  end

  # Stands in for html_response(get(conn, path), 200): the view only loads the
  # post once connected, so the static page has a placeholder and no title.
  defp disconnected_render(_post) do
    "<h1></h1><p>Loading...</p>"
  end

  test "bad: asserts on the connected render only" do
    post = %{title: "Hello LiveView", body: "Full content"}

    # In a real test: {:ok, _view, html} = live(conn, ~p"/posts/#{post.id}")
    html = connected_render(post)

    assert html =~ "Hello LiveView"
    # Passes. Nothing looked at the static HTML.
  end

  test "bad: the static page is missing the title and no test notices" do
    post = %{title: "Hello LiveView", body: "Full content"}

    assert connected_render(post) =~ "Hello LiveView"

    # The page crawlers and link previews read has no title. An assertion on
    # html_response(get(conn, path), 200) would have caught it.
    refute disconnected_render(post) =~ "Hello LiveView"
  end
end
