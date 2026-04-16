# EXPECTED: passes
# BAD PRACTICE: GraphQL query strings defined inline inside each test body.
# The same query is duplicated across tests, and a schema change requires
# editing every test that uses it.
Mix.install([])

ExUnit.start(autorun: true)

# Simulated schema executor
defmodule AbsAttrsBad.Schema do
  def run(query_string, variables) do
    cond do
      String.contains?(query_string, "getPost") ->
        id = variables["id"]
        {:ok, %{data: %{"post" => %{"id" => id, "title" => "Post #{id}", "body" => "Body #{id}"}}}}

      String.contains?(query_string, "createPost") ->
        title = variables["title"]
        {:ok, %{data: %{"createPost" => %{"id" => "new-1", "title" => title}}}}

      true ->
        {:error, "unknown query"}
    end
  end
end

defmodule AbsAttrsBad.PostsTest do
  use ExUnit.Case, async: true

  alias AbsAttrsBad.Schema

  # BAD: query string inline — duplicated in every test

  test "bad: returns post title — query string inline" do
    # Duplicated query string — if schema renames `title` to `headline`,
    # this must be updated here AND in every other test
    assert {:ok, %{data: %{"post" => %{"title" => "Post 42"}}}} =
             Schema.run(
               "query getPost($id: ID!) { post(id: $id) { id title body } }",
               %{"id" => "42"}
             )
  end

  test "bad: returns post body — same query string duplicated" do
    # Exact same query string as above — a field rename means two edits
    assert {:ok, %{data: %{"post" => %{"body" => "Body 42"}}}} =
             Schema.run(
               "query getPost($id: ID!) { post(id: $id) { id title body } }",
               %{"id" => "42"}
             )
  end

  test "bad: different id — third copy of the same query string" do
    # Now there are three identical query strings. Adding a field requires
    # three edits, and missing one causes inconsistency.
    assert {:ok, %{data: %{"post" => %{"id" => "99"}}}} =
             Schema.run(
               "query getPost($id: ID!) { post(id: $id) { id title body } }",
               %{"id" => "99"}
             )
  end

  test "bad: create post — mutation inline, not a module attribute" do
    # This mutation string is unreusable — if a second test needs it,
    # there will be a fourth inline string literal.
    assert {:ok, %{data: %{"createPost" => %{"title" => "New"}}}} =
             Schema.run(
               "mutation createPost($title: String!) { createPost(title: $title, body: \"b\") { id title } }",
               %{"title" => "New"}
             )
  end
end
