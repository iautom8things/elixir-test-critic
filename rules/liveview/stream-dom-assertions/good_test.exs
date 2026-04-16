# EXPECTED: passes
Mix.install([])

# Demonstrates: asserting on DOM content for streams rather than on assigns.
#
# In a real Phoenix LiveView test:
#
#   test "displays all posts in the stream", %{conn: conn} do
#     posts = insert_list(3, :post)
#     {:ok, view, html} = live(conn, ~p"/posts")
#
#     # Good: assert on the rendered HTML — what the DOM actually contains
#     for post <- posts do
#       assert html =~ post.title
#     end
#
#     assert has_element?(view, "[data-role='post-item']")
#   end
#
#   test "removes a post from the stream", %{conn: conn} do
#     post = insert(:post, title: "To Be Deleted")
#     {:ok, view, _html} = live(conn, ~p"/posts")
#
#     view |> element("[data-role='delete'][data-id='#{post.id}']") |> render_click()
#
#     refute has_element?(view, "#post-#{post.id}")
#     refute render(view) =~ "To Be Deleted"
#   end
#
# Stream assigns are pruned after the initial render — only the DOM is authoritative.

ExUnit.start(autorun: true)

defmodule StreamDomAssertionsGoodTest do
  use ExUnit.Case, async: true

  # Simulate a rendered stream — items appear in the HTML
  defp render_stream(items) do
    Enum.map_join(items, "\n", fn item ->
      ~s(<li id="post-#{item.id}" data-role="post-item">#{item.title}</li>)
    end)
  end

  defp has_element?(html, selector) do
    String.contains?(html, selector)
  end

  defp remove_from_dom(html, id) do
    # Simulate stream_delete — item removed from the rendered HTML
    String.replace(html, ~r/<li id="post-#{id}"[^>]*>.*?<\/li>/s, "")
  end

  test "good: assert all stream items appear in the rendered HTML" do
    posts = [
      %{id: 1, title: "First Post"},
      %{id: 2, title: "Second Post"},
      %{id: 3, title: "Third Post"}
    ]

    html = render_stream(posts)

    for post <- posts do
      assert html =~ post.title, "Expected #{post.title} in stream render"
    end
  end

  test "good: assert element presence using has_element? pattern" do
    posts = [%{id: 10, title: "Stream Item"}]
    html = render_stream(posts)

    assert has_element?(html, ~s(data-role="post-item"))
    assert has_element?(html, ~s(id="post-10"))
  end

  test "good: after delete, assert item is absent from the DOM" do
    posts = [%{id: 5, title: "Keep Me"}, %{id: 6, title: "Delete Me"}]
    html = render_stream(posts)

    # Simulate stream_delete for post 6
    html_after_delete = remove_from_dom(html, 6)

    assert html_after_delete =~ "Keep Me"
    refute html_after_delete =~ "Delete Me"
    refute has_element?(html_after_delete, ~s(id="post-6"))
  end
end
