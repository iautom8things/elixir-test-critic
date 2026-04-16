# EXPECTED: passes
# BAD PRACTICE: Only testing the happy path for a protected resolver.
# Unauthorized and wrong-role paths are never tested, leaving the authorization
# boundary completely unverified. This is the most dangerous gap in a GraphQL
# API test suite.
Mix.install([])

ExUnit.start(autorun: true)

# Resolver WITH an authorization bug — no check for unauthenticated access
defmodule AbsAuthBad.Resolvers.Posts do
  # BUG: this resolver has no authorization check at all
  # It happily deletes for anyone, including unauthenticated callers
  def delete_post(%{id: post_id}, _resolution) do
    {:ok, %{id: post_id, title: "Deleted post"}}
  end
end

defmodule AbsAuthBad.HappyPathOnlyTest do
  use ExUnit.Case, async: true

  alias AbsAuthBad.Resolvers.Posts

  # BAD: only the happy path is tested
  test "bad: admin can delete post — only happy path, no auth boundary tested" do
    admin = %{id: 1, role: :admin}
    resolution = %{context: %{current_user: admin}}

    # This passes — but so would an unauthenticated call, because the resolver
    # has no auth check. We never discover the bug.
    assert {:ok, %{id: "42"}} = Posts.delete_post(%{id: "42"}, resolution)
  end

  test "bad: demonstrates the missing auth check — unauthenticated call succeeds" do
    # No current_user — this should be rejected, but the resolver doesn't check.
    # Because we only test the happy path, this bug ships to production.
    empty_context = %{context: %{}}

    # This succeeds when it should return {:error, "unauthorized"}
    assert {:ok, _deleted} = Posts.delete_post(%{id: "42"}, empty_context)

    # The test passes (the resolver has no auth check), but this is the bug:
    # In production, unauthenticated users can delete any post.
    # A proper test would assert {:error, _} here.
  end

  test "bad: demonstrates missing role check — wrong-role call also succeeds" do
    regular_user = %{id: 99, role: :user}
    resolution = %{context: %{current_user: regular_user}}

    # Should fail for regular users deleting arbitrary posts, but doesn't
    assert {:ok, _deleted} = Posts.delete_post(%{id: "1"}, resolution)
  end
end
