# EXPECTED: passes
Mix.install([])

# Demonstrates: the render_async pattern for async assigns in LiveView tests.
#
# In a real Phoenix LiveView test:
#
#   test "shows orders after async load", %{conn: conn} do
#     user = insert(:user)
#     insert(:order, user: user, number: "1001")
#     {:ok, view, html} = live(conn, ~p"/users/#{user.id}/orders")
#
#     # html here shows the loading state
#     assert html =~ "Loading orders..."
#
#     # Drive async tasks to completion
#     render_async(view)
#
#     # Now assert on the loaded content
#     assert render(view) =~ "Order #1001"
#   end
#
#   test "shows loading indicator before async completes", %{conn: conn} do
#     user = insert(:user)
#     {:ok, _view, html} = live(conn, ~p"/users/#{user.id}/orders")
#
#     # Valid: assert on loading state without calling render_async
#     assert html =~ "Loading orders..."
#   end

ExUnit.start(autorun: true)

defmodule RenderAsyncGoodTest do
  use ExUnit.Case, async: true

  # Simulate the three states of an async assign
  defmodule AsyncState do
    defstruct [:loading, :ok, :failed]
    def loading, do: %__MODULE__{loading: true}
    def result(value), do: %__MODULE__{ok: value}
  end

  defp render_loading(_state = %AsyncState{loading: true}), do: "Loading orders..."
  defp render_loading(_state = %AsyncState{ok: orders}), do: Enum.join(orders, ", ")

  defp run_async_task(initial_state) do
    # Simulate async task completing
    receive do
      :complete -> AsyncState.result(["Order #1001", "Order #1002"])
    after
      0 -> initial_state
    end
  end

  test "good: assert on result only after async task completes" do
    state = AsyncState.loading()

    # Initial render shows loading state
    initial_html = render_loading(state)
    assert initial_html == "Loading orders..."

    # Simulate render_async: drive the task to completion
    send(self(), :complete)
    final_state = run_async_task(state)
    final_html = render_loading(final_state)

    # Now we can assert on the loaded content
    assert final_html =~ "Order #1001"
    assert final_html =~ "Order #1002"
  end

  test "good: test loading state explicitly without running async" do
    state = AsyncState.loading()

    # This is valid: we want to verify the loading indicator
    html = render_loading(state)
    assert html == "Loading orders..."

    # We intentionally do NOT call render_async here — that's the point of this test
  end

  test "good: render_async is idempotent when no async tasks are pending" do
    # If there are no pending async tasks, render_async returns the current render
    # harmlessly. Safe to call defensively.
    state = AsyncState.result(["Order #999"])
    html = render_loading(state)
    assert html =~ "Order #999"
  end
end
