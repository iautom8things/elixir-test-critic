# EXPECTED: passes
Mix.install([])

# Demonstrates: using ~p verified routes vs. hardcoded strings.
#
# In a real Phoenix ConnCase test, ~p"/users/#{user.id}" is verified against
# the router at compile time. If the route is renamed or removed, you get a
# compile error immediately rather than a runtime 404 that might still pass.
#
# Real example:
#
#   use MyAppWeb.ConnCase, async: true
#
#   test "shows user", %{conn: conn} do
#     user = insert(:user)
#     conn = get(conn, ~p"/users/#{user.id}")        # ✓ verified
#     assert html_response(conn, 200) =~ user.name
#   end
#
#   test "redirect target is verified", %{conn: conn} do
#     conn = get(conn, ~p"/dashboard")
#     assert redirected_to(conn) == ~p"/login"       # ✓ both sides verified
#   end

ExUnit.start(autorun: true)

defmodule VerifiedRoutesConceptTest do
  use ExUnit.Case, async: true

  # Simulate what ~p produces: a path string, but validated at compile time.
  # In tests, the benefit is compile-time checking — we can't replicate that
  # without a router, but we can show the pattern is simply about using the sigil.

  test "~p sigil produces the correct path string" do
    # In a real app: ~p"/users/#{user.id}" expands to "/users/42" at runtime
    # Here we just show that the resulting value is a plain string.
    user_id = 42
    path = "/users/#{user_id}"   # what ~p expands to
    assert path == "/users/42"
  end

  test "interpolation in routes produces clean paths" do
    # ~p"/posts/#{post.id}/comments/#{comment.id}" works the same way
    post_id = 7
    comment_id = 99
    path = "/posts/#{post_id}/comments/#{comment_id}"
    assert path == "/posts/7/comments/99"
  end

  test "redirect assertions use the same ~p pattern on both sides" do
    # Good: assert redirected_to(conn) == ~p"/login"
    # Both the actual redirect and the expected value go through the same
    # verification. Simulated here as two strings that must match.
    redirect_location = "/login"
    expected = "/login"
    assert redirect_location == expected
  end
end
