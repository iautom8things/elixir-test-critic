# EXPECTED: passes
# BAD PRACTICE: Asserting on socket.assigns.streams rather than on the rendered DOM.
# Stream items are pruned from server assigns after being sent to the client.
# These assertions are unreliable after the initial render cycle.
Mix.install([])

ExUnit.start(autorun: true)

defmodule StreamAssignsAssertionBadTest do
  use ExUnit.Case, async: true

  # Simulate the server-side stream state after initial mount
  # (items are present in inserts during mount, then cleared)
  defmodule FakeStream do
    # After the initial render, the stream buffer is pruned
    def post_mount_assigns do
      %{
        streams: %{
          posts: %{
            # After mount, inserts is cleared — items were sent to the DOM
            inserts: [],
            deletes: [],
            reset: false
          }
        }
      }
    end

    # What the DOM actually contains (simulated as rendered HTML)
    def dom_html do
      """
      <li id="post-1">First Post</li>
      <li id="post-2">Second Post</li>
      <li id="post-3">Third Post</li>
      """
    end
  end

  test "bad: asserting on stream assigns after mount gives wrong count" do
    assigns = FakeStream.post_mount_assigns()

    # After the initial render, inserts is empty — items were pruned.
    # This assertion fails (0 != 3) even though the DOM shows 3 items.
    inserts = assigns.streams.posts.inserts
    assert length(inserts) == 0  # passes, but for the wrong reason

    # The DOM has 3 items — the assigns are misleading
    dom = FakeStream.dom_html()
    assert dom =~ "First Post"
    assert dom =~ "Second Post"
    assert dom =~ "Third Post"
  end

  test "bad: stream inserts count is not the source of truth for DOM state" do
    assigns = FakeStream.post_mount_assigns()

    # A developer might write: assert length(view.assigns.streams.posts.inserts) == 3
    # This would fail — inserts reflects what was sent in the LAST diff, not total DOM items.
    inserts_in_assigns = assigns.streams.posts.inserts

    # Proves the mismatch:
    dom_item_count = FakeStream.dom_html() |> String.split("<li") |> length() |> Kernel.-(1)
    assert dom_item_count == 3
    assert length(inserts_in_assigns) == 0  # assigns and DOM are out of sync
  end

  test "demonstrates: DOM is the correct assertion target" do
    dom = FakeStream.dom_html()

    # Correct approach: assert on the rendered HTML
    assert dom =~ "First Post"
    assert dom =~ "post-1"
    refute dom =~ "Fourth Post"
  end
end
