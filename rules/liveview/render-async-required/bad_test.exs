# EXPECTED: passes
# BAD PRACTICE: Asserting on async-loaded content without calling render_async.
# The test sees only the loading state. Adding Process.sleep is the typical
# (wrong) workaround — making tests slow and still potentially flaky.
Mix.install([])

ExUnit.start(autorun: true)

defmodule RenderAsyncMissingBadTest do
  use ExUnit.Case, async: true

  defmodule AsyncState do
    defstruct [:loading, :ok]
    def loading, do: %__MODULE__{loading: true}
    def result(value), do: %__MODULE__{ok: value}
  end

  defp render_html(%AsyncState{loading: true}), do: "Loading orders..."
  defp render_html(%AsyncState{ok: orders}), do: Enum.join(orders, ", ")

  test "bad: asserts on async content before render_async — sees only loading state" do
    state = AsyncState.loading()
    html = render_html(state)

    # This would fail in a real LiveView test:
    # assert render(view) =~ "Order #1001"   ← fails: content not loaded yet
    #
    # The test sees "Loading orders..." because render_async was not called.
    # We assert this to show what a real test would incorrectly see.
    assert html == "Loading orders..."
    refute html =~ "Order #1001"  # content is missing — a real test would fail here
  end

  test "bad: using Process.sleep to work around missing render_async" do
    state = AsyncState.loading()

    # Simulating the wrong fix: sleep and hope the async task finishes.
    # In LiveViewTest, async tasks don't run on their own — sleep does nothing.
    # In a real app with a real timer, this is slow and flaky under load.
    Process.sleep(50)  # ← wrong fix

    html = render_html(state)

    # Still loading! Because in LiveViewTest, Process.sleep doesn't advance
    # async tasks — only render_async does.
    assert html == "Loading orders..."
    refute html =~ "Order #1001"
  end

  test "demonstrates: the correct fix is render_async, not sleep" do
    state = AsyncState.loading()

    # The fix: simulate what render_async does — run the async task
    # and get the resulting HTML.
    completed_state = AsyncState.result(["Order #1001"])
    html = render_html(completed_state)

    assert html =~ "Order #1001"
    refute html =~ "Loading"
  end
end
