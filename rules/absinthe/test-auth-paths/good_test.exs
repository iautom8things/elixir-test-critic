# EXPECTED: passes
# Demonstrates: testing all three authorization paths for a protected resolver —
# authenticated happy path, unauthenticated access, and wrong-role access.
#
# In a real Absinthe app:
#
#   test "admin can delete post" do
#     assert {:ok, %{data: ...}} = Absinthe.run(@mutation, Schema, context: %{current_user: admin})
#   end
#   test "unauthenticated cannot delete" do
#     assert {:ok, %{errors: [%{message: "unauthorized"}]}} = Absinthe.run(@mutation, Schema, context: %{})
#   end
#   test "regular user cannot delete another's post" do
#     assert {:ok, %{errors: [%{message: "unauthorized"}]}} = Absinthe.run(@mutation, Schema, context: %{current_user: user})
#   end
Mix.install([])

ExUnit.start(autorun: true)

# Simulated resolver with authorization logic
defmodule AbsAuthGood.Resolvers.Posts do
  def delete_post(%{id: post_id}, %{context: context}) do
    case context do
      %{current_user: %{role: :admin}} ->
        {:ok, %{id: post_id, title: "Deleted post"}}

      %{current_user: %{role: :user, id: user_id}} ->
        # In real app: check if the post belongs to this user
        # Here we simulate: users can only delete their own posts (id matches)
        if to_string(user_id) == to_string(post_id) do
          {:ok, %{id: post_id, title: "Deleted post"}}
        else
          {:error, "unauthorized: you can only delete your own posts"}
        end

      _ ->
        {:error, "unauthorized: authentication required"}
    end
  end
end

defmodule AbsAuthGood.AuthPathsTest do
  use ExUnit.Case, async: true

  alias AbsAuthGood.Resolvers.Posts

  # Path 1: Authenticated happy path — admin succeeds
  test "admin can delete any post" do
    admin = %{id: 1, role: :admin, email: "admin@example.com"}
    context = %{context: %{current_user: admin}}

    assert {:ok, %{id: "42"}} = Posts.delete_post(%{id: "42"}, context)
  end

  # Path 2: Unauthenticated access is rejected
  test "unauthenticated user cannot delete a post" do
    context = %{context: %{}}

    assert {:error, message} = Posts.delete_post(%{id: "42"}, context)
    assert message =~ "unauthorized"
    assert message =~ "authentication required"
  end

  # Path 3: Wrong user access is rejected (ownership check)
  test "regular user cannot delete another user's post" do
    user = %{id: 99, role: :user, email: "user@example.com"}
    context = %{context: %{current_user: user}}
    # Post id "42" doesn't match user id 99
    assert {:error, message} = Posts.delete_post(%{id: "42"}, context)
    assert message =~ "unauthorized"
    assert message =~ "own posts"
  end

  # Path 3b: Correct user can delete their own post
  test "regular user can delete their own post" do
    user = %{id: 42, role: :user, email: "user@example.com"}
    context = %{context: %{current_user: user}}

    assert {:ok, %{id: 42}} = Posts.delete_post(%{id: 42}, context)
  end
end
