# EXPECTED: passes
Mix.install([])

# Demonstrates: the two-phase test pattern for LiveView — disconnected then connected.
#
# In a real Phoenix app:
#
#   test "renders disconnected and connected", %{conn: conn} do
#     post = insert(:post, title: "Hello")
#
#     # Phase 1: disconnected render (static HTTP GET)
#     conn = get(conn, ~p"/posts/#{post.id}")
#     assert html_response(conn, 200) =~ "Hello"
#
#     # Phase 2: connected render (WebSocket upgrade)
#     {:ok, view, _html} = live(conn)
#     assert render(view) =~ "Hello"
#   end
#
# The disconnected phase catches:
#   - mount/3 crashes that only happen on HTTP (before socket is connected)
#   - missing assigns in the connected?/1 == false branch
#   - SEO/crawler-visible content
#
# The connected phase catches:
#   - handle_info/handle_event wiring
#   - async assign loading (render_async)
#   - interactive state

ExUnit.start(autorun: true)

defmodule DisconnectedConnectedRenderTest do
  use ExUnit.Case, async: true

  # Simulate the two-phase content production to show the pattern
  defp disconnected_render(post) do
    # In real Phoenix: html_response(conn, 200) after get(conn, path)
    "<html><body><h1>#{post.title}</h1><p>Loading...</p></body></html>"
  end

  defp connected_render(post) do
    # In real Phoenix: render(view) after live(conn)
    "<h1>#{post.title}</h1><p>#{post.body}</p><button>Like</button>"
  end

  test "disconnected render contains the post title" do
    post = %{title: "Hello LiveView", body: "Full content here"}

    html = disconnected_render(post)

    assert html =~ "Hello LiveView"
    # Loading state is visible in disconnected render
    assert html =~ "Loading..."
  end

  test "connected render contains full content and interactive elements" do
    post = %{title: "Hello LiveView", body: "Full content here"}

    html = connected_render(post)

    assert html =~ "Hello LiveView"
    assert html =~ "Full content here"
    # Interactive elements only appear after connection
    assert html =~ "<button>Like</button>"
  end

  test "both renders share the essential content" do
    post = %{title: "Shared Title", body: "Body text"}

    disconnected = disconnected_render(post)
    connected = connected_render(post)

    # The title must appear in both phases
    assert disconnected =~ post.title
    assert connected =~ post.title
  end
end
