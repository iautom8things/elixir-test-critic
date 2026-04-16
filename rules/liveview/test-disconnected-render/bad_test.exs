# EXPECTED: passes
# BAD PRACTICE: Testing only the connected LiveView render. The disconnected
# (static HTTP) render is never exercised, leaving SEO content and mount
# errors in the HTTP-only path completely untested.
Mix.install([])

ExUnit.start(autorun: true)

defmodule ConnectedOnlyRenderTest do
  use ExUnit.Case, async: true

  defp connected_render(post) do
    "<h1>#{post.title}</h1><p>#{post.body}</p>"
  end

  # Simulate the disconnected_render having a bug that only appears in HTTP mode
  defp disconnected_render_with_bug(_post) do
    raise "crash during HTTP render — mount/3 with connected?(socket) == false raises"
  end

  test "bad: only tests connected state — misses disconnected render entirely" do
    post = %{title: "Hello LiveView", body: "Full content"}

    # In a real test: {:ok, view, html} = live(conn, ~p"/posts/#{post.id}")
    # This only exercises the WebSocket-connected mount.
    html = connected_render(post)

    assert html =~ "Hello LiveView"
    # Test passes! But the HTTP GET (disconnected) path is never tested.
  end

  test "bad: a bug in disconnected render goes undetected" do
    post = %{title: "Hello LiveView", body: "Full content"}

    # The disconnected render raises, but because we never call get(conn, path),
    # we never discover it. The connected render works fine.
    connected_html = connected_render(post)
    assert connected_html =~ "Hello LiveView"

    # If we had also tested the disconnected render:
    #   assert_raise RuntimeError, fn -> disconnected_render_with_bug(post) end
    # we would catch the crash. But we don't, so it ships.
    assert true  # test passes; real bug is invisible
  end
end
