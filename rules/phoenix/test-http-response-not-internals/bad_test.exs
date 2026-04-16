# EXPECTED: passes
# BAD PRACTICE: These tests assert on conn.assigns (internal controller state)
# rather than the HTTP response. They will break on refactors that don't change
# the user-visible output.
Mix.install([])

ExUnit.start(autorun: true)

defmodule HttpResponseInternalsTest do
  use ExUnit.Case, async: true

  defp simulate_show_action(status, body) do
    %{status: status, resp_body: body, assigns: %{user: %{id: 1, name: "Ada"}, page_title: "Ada's Profile"}}
  end

  test "bad: reaches into conn.assigns instead of reading the HTTP response" do
    conn = simulate_show_action(200, "<h1>Ada</h1>")

    # This couples the test to the controller's internal assign names.
    # If the controller renames :user to :current_user, this breaks — even
    # though the response is identical.
    assert conn.assigns.user.name == "Ada"
    assert conn.assigns.page_title == "Ada's Profile"

    # The status IS part of the contract, but we forgot to assert on it.
    # We are testing internals, not the HTTP surface.
  end

  test "bad: ignores status code, only checks assign" do
    # A controller bug could return 500 with the assigns still populated;
    # this test would pass despite the server error.
    conn = simulate_show_action(500, "Internal Server Error")

    # Still passes! conn.assigns is populated even on error responses.
    assert conn.assigns.user.name == "Ada"
  end
end
