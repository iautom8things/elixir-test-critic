# EXPECTED: passes
# Demonstrates: testing context functions directly rather than through resolvers.
#
# In a real Absinthe app the resolver is a thin pass-through:
#
#   def create_post(%{title: title, body: body}, _resolution) do
#     MyApp.Posts.create_post(%{title: title, body: body})
#   end
#
# And the tests hit the context module directly — no GraphQL overhead:
#
#   test "rejects titles shorter than 3 characters" do
#     assert {:error, :title_too_short} = Posts.create_post(%{title: "Hi", body: "body"})
#   end
#
# This script demonstrates the pattern with plain Elixir.
Mix.install([])

ExUnit.start(autorun: true)

# Simulated context module — pure Elixir business logic
defmodule AbsGoodCtx.Posts do
  defstruct [:id, :title, :body, :published]

  def create_post(%{title: title}) when byte_size(title) < 3 do
    {:error, :title_too_short}
  end

  def create_post(%{title: title, body: body}) do
    post = %__MODULE__{id: System.unique_integer([:positive]), title: title, body: body, published: false}
    {:ok, post}
  end

  def get_post(id) when is_integer(id) and id > 0 do
    {:ok, %__MODULE__{id: id, title: "Fetched post", body: "body", published: true}}
  end

  def get_post(_id), do: {:error, :not_found}
end

# Simulated thin resolver — only delegates, no logic of its own
defmodule AbsGoodCtx.Resolvers.Posts do
  alias AbsGoodCtx.Posts

  def create_post(%{title: title, body: body}, _resolution) do
    Posts.create_post(%{title: title, body: body})
  end

  def get_post(%{id: id}, _resolution) do
    Posts.get_post(id)
  end
end

defmodule AbsGoodCtx.PostsContextTest do
  use ExUnit.Case, async: true

  alias AbsGoodCtx.Posts

  # Tests hit the context directly — fast, no GraphQL overhead
  test "create_post/1 rejects titles shorter than 3 characters" do
    assert {:error, :title_too_short} = Posts.create_post(%{title: "Hi", body: "some body"})
  end

  test "create_post/1 rejects empty title" do
    assert {:error, :title_too_short} = Posts.create_post(%{title: "", body: "body"})
  end

  test "create_post/1 creates post with valid attributes" do
    assert {:ok, post} = Posts.create_post(%{title: "Hello World", body: "Full body text"})
    assert post.title == "Hello World"
    assert post.published == false
  end

  test "get_post/1 returns not_found for invalid id" do
    assert {:error, :not_found} = Posts.get_post(-1)
  end

  test "get_post/1 returns post for valid id" do
    assert {:ok, post} = Posts.get_post(42)
    assert post.id == 42
  end
end

defmodule AbsGoodCtx.ResolverWiringTest do
  use ExUnit.Case, async: true

  alias AbsGoodCtx.Resolvers.Posts, as: Resolver

  # A small number of integration-style tests verify resolver wiring
  test "resolver delegates create_post to context" do
    assert {:ok, post} = Resolver.create_post(%{title: "Wired up", body: "body"}, %{})
    assert post.title == "Wired up"
  end

  test "resolver propagates context errors" do
    assert {:error, :title_too_short} = Resolver.create_post(%{title: "No", body: "body"}, %{})
  end
end
