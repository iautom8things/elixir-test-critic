# EXPECTED: passes
Mix.install([])

# Demonstrates: asserting on the HTTP response (status, body) — the public contract —
# rather than on conn.assigns or internal state.
#
# In a real Phoenix app:
#
#   test "shows a user's profile page", %{conn: conn} do
#     user = insert(:user, name: "Ada")
#     conn = get(conn, ~p"/users/#{user.id}")
#
#     assert html_response(conn, 200) =~ "Ada"
#   end
#
#   test "returns user JSON", %{conn: conn} do
#     user = insert(:user, name: "Ada")
#     conn = get(conn, ~p"/api/users/#{user.id}")
#
#     assert %{"name" => "Ada"} = json_response(conn, 200)
#   end
#
#   test "redirects unauthenticated requests", %{conn: conn} do
#     conn = get(conn, ~p"/dashboard")
#     assert redirected_to(conn) == ~p"/login"
#   end
#
# The pattern: use html_response/2, json_response/2, redirected_to/1 to inspect
# the HTTP layer. Never reach into conn.assigns.

ExUnit.start(autorun: true)

defmodule HttpResponsePublicContractTest do
  use ExUnit.Case, async: true

  # Simulate what a controller action produces: a conn-like map
  defp simulate_show_action(status, body) do
    %{status: status, resp_body: body, assigns: %{user: %{id: 1, name: "Ada"}}}
  end

  defp simulate_redirect_action(to) do
    %{status: 302, resp_body: "", halted: true, resp_headers: [{"location", to}]}
  end

  test "good: asserts on HTTP status and body content" do
    conn = simulate_show_action(200, "<h1>Ada</h1>")

    # Assert on HTTP response — the public contract
    assert conn.status == 200
    assert conn.resp_body =~ "Ada"
  end

  test "good: asserts on redirect location" do
    conn = simulate_redirect_action("/login")

    assert conn.status == 302
    location = conn.resp_headers |> Enum.find(fn {k, _} -> k == "location" end) |> elem(1)
    assert location == "/login"
  end

  test "good: asserts on JSON shape, not internal assigns" do
    # In a real test: json_response(conn, 200) returns decoded JSON
    # Here we simulate that decoded JSON map
    json_payload = %{"name" => "Ada", "email" => "ada@example.com"}

    assert %{"name" => "Ada"} = json_payload
    # Note: we do NOT assert on conn.assigns.user — that's internal
  end
end
