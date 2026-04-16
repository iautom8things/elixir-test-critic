# EXPECTED: passes
# Demonstrates: defining GraphQL query strings as @module_attributes rather
# than inline string literals in each test body.
#
# In a real Absinthe test module:
#
#   @post_query """
#   query GetPost($id: ID!) { post(id: $id) { title body } }
#   """
#
#   test "returns title" do
#     Absinthe.run(@post_query, Schema, variables: %{"id" => id})
#   end
#
# This script demonstrates the pattern with plain Elixir.
Mix.install([])

ExUnit.start(autorun: true)

# Simulated schema executor
defmodule AbsAttrsGood.Schema do
  def run(query_string, variables) do
    cond do
      String.contains?(query_string, "getPost") ->
        id = variables["id"] || variables[:id]
        {:ok, %{data: %{"post" => %{"id" => id, "title" => "Post #{id}", "body" => "Body #{id}"}}}}

      String.contains?(query_string, "createPost") ->
        title = variables["title"]
        {:ok, %{data: %{"createPost" => %{"id" => "new-1", "title" => title}}}}

      String.contains?(query_string, "deletePost") ->
        id = variables["id"]
        {:ok, %{data: %{"deletePost" => %{"id" => id}}}}

      true ->
        {:error, "unknown query"}
    end
  end
end

defmodule AbsAttrsGood.PostsTest do
  use ExUnit.Case, async: true

  alias AbsAttrsGood.Schema

  # GOOD: queries defined once as module attributes, reused across tests
  @post_query """
  query getPost($id: ID!) {
    post(id: $id) {
      id
      title
      body
    }
  }
  """

  @create_post_mutation """
  mutation createPost($title: String!, $body: String!) {
    createPost(title: $title, body: $body) {
      id
      title
    }
  }
  """

  @delete_post_mutation """
  mutation deletePost($id: ID!) {
    deletePost(id: $id) {
      id
    }
  }
  """

  test "returns post title using module attribute query" do
    assert {:ok, %{data: %{"post" => %{"title" => "Post 42"}}}} =
             Schema.run(@post_query, %{"id" => "42"})
  end

  test "returns post body using the same module attribute query" do
    # GOOD: reusing @post_query — no duplication, single point of change
    assert {:ok, %{data: %{"post" => %{"body" => "Body 42"}}}} =
             Schema.run(@post_query, %{"id" => "42"})
  end

  test "returns post for different id using same query" do
    assert {:ok, %{data: %{"post" => %{"id" => "99"}}}} =
             Schema.run(@post_query, %{"id" => "99"})
  end

  test "creates post using mutation module attribute" do
    assert {:ok, %{data: %{"createPost" => %{"title" => "New Post"}}}} =
             Schema.run(@create_post_mutation, %{"title" => "New Post", "body" => "Body"})
  end

  test "deletes post using mutation module attribute" do
    assert {:ok, %{data: %{"deletePost" => %{"id" => "5"}}}} =
             Schema.run(@delete_post_mutation, %{"id" => "5"})
  end
end
