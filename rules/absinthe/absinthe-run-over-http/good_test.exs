# EXPECTED: passes
# Demonstrates: preferring Absinthe.run/3 over HTTP for schema tests, and
# reserving HTTP tests for transport-level concerns.
#
# In a real app the split looks like:
#
#   # Schema logic — fast, direct
#   Absinthe.run(@query, MyApp.Schema, context: %{current_user: user})
#
#   # Transport layer — only when testing Plug/HTTP concerns
#   post(conn, "/api", %{query: @query})
#
# This script demonstrates the pattern with plain Elixir (no Absinthe dep).
Mix.install([])

ExUnit.start(autorun: true)

# Simulated schema executor (models Absinthe.run/3 behaviour)
defmodule AbsRunGood.SchemaExecutor do
  @posts %{
    "1" => %{"id" => "1", "title" => "Hello World", "published" => true},
    "2" => %{"id" => "2", "title" => "Draft Post", "published" => false}
  }

  def run("get_post", %{"id" => id}, context) do
    case Map.get(@posts, id) do
      nil ->
        {:ok, %{data: nil, errors: [%{message: "Post not found"}]}}

      post ->
        if context[:current_user] do
          {:ok, %{data: %{"post" => post}}}
        else
          {:ok, %{data: nil, errors: [%{message: "Unauthorized"}]}}
        end
    end
  end

  def run("get_posts", _vars, context) do
    if context[:current_user] do
      posts = Map.values(@posts)
      {:ok, %{data: %{"posts" => posts}}}
    else
      {:ok, %{data: nil, errors: [%{message: "Unauthorized"}]}}
    end
  end
end

# Simulated HTTP layer (models ConnCase behaviour)
defmodule AbsRunGood.HttpLayer do
  alias AbsRunGood.SchemaExecutor

  def post_graphql(query_name, variables, headers) do
    auth = Map.get(headers, "authorization")

    context =
      if auth && String.starts_with?(auth, "Bearer ") do
        %{current_user: %{id: 1, email: "test@example.com"}}
      else
        %{}
      end

    case SchemaExecutor.run(query_name, variables, context) do
      {:ok, %{errors: errors}} when errors != [] ->
        %{status: 200, body: %{"errors" => errors}}

      {:ok, result} ->
        %{status: 200, body: result}
    end
  end
end

defmodule AbsRunGood.SchemaTest do
  use ExUnit.Case, async: true

  alias AbsRunGood.SchemaExecutor

  # GOOD: schema logic tested directly via run/3 equivalent — fast, no HTTP
  test "returns post data with authenticated context" do
    context = %{current_user: %{id: 1}}

    assert {:ok, %{data: %{"post" => %{"title" => "Hello World"}}}} =
             SchemaExecutor.run("get_post", %{"id" => "1"}, context)
  end

  test "returns error when post not found" do
    context = %{current_user: %{id: 1}}

    assert {:ok, %{data: nil, errors: [%{message: "Post not found"}]}} =
             SchemaExecutor.run("get_post", %{"id" => "999"}, context)
  end

  test "returns unauthorized error with empty context" do
    assert {:ok, %{data: nil, errors: [%{message: "Unauthorized"}]}} =
             SchemaExecutor.run("get_post", %{"id" => "1"}, %{})
  end

  test "returns list of posts for authenticated user" do
    context = %{current_user: %{id: 1}}

    assert {:ok, %{data: %{"posts" => posts}}} =
             SchemaExecutor.run("get_posts", %{}, context)

    assert length(posts) == 2
  end
end

defmodule AbsRunGood.HttpTransportTest do
  use ExUnit.Case, async: true

  alias AbsRunGood.HttpLayer

  # GOOD: HTTP tests cover only transport-level concerns
  test "requires Authorization header — transport-level concern" do
    response = HttpLayer.post_graphql("get_post", %{"id" => "1"}, %{})

    assert response.status == 200
    assert [%{message: "Unauthorized"}] = response.body["errors"]
  end

  test "accepts valid Bearer token" do
    headers = %{"authorization" => "Bearer valid-token"}
    response = HttpLayer.post_graphql("get_post", %{"id" => "1"}, headers)

    assert response.status == 200
    assert response.body.data["post"]["title"] == "Hello World"
  end
end
