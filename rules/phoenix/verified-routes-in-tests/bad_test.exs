# EXPECTED: passes
# BAD PRACTICE: Tests use hardcoded string paths instead of ~p verified routes.
# If a route is renamed, these tests continue to compile and run but now hit
# an unexpected endpoint (or 404), producing misleading results.
Mix.install([])

ExUnit.start(autorun: true)

defmodule HardcodedRoutesTest do
  use ExUnit.Case, async: true

  test "bad: hardcoded path gives no compile-time safety" do
    user_id = 42

    # If the router changes /users to /accounts, this string stays wrong.
    # No compiler warning. The test hits a 404 and may still pass if the
    # assertion is loose enough.
    path = "/users/#{user_id}"
    assert is_binary(path)   # passes, but no safety guarantee
  end

  test "bad: redirect assertion uses hardcoded string" do
    # In a real test: assert redirected_to(conn) == "/login"
    # If /login is renamed to /sign-in, this assertion fails at runtime —
    # but only when the test runs, not at compile time.
    redirect_location = "/login"
    assert redirect_location == "/login"  # passes now, breaks silently after rename
  end

  test "bad: deeply nested hardcoded path" do
    post_id = 5
    # "/posts/:id/edit" might be renamed — no safety net
    path = "/posts/#{post_id}/edit"
    assert String.starts_with?(path, "/posts/")
  end
end
