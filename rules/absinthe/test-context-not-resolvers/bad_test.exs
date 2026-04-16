# EXPECTED: passes
# BAD PRACTICE: Business logic lives inside the resolver rather than in a
# context module. Tests must simulate the full resolver call path to reach
# validation logic, and the logic is not reusable from other callers.
Mix.install([])

ExUnit.start(autorun: true)

# BAD: resolver contains business logic that belongs in a context module
defmodule AbsBadCtx.Resolvers.Posts do
  defstruct [:id, :title, :body, :published]

  # Logic is buried here — only reachable via GraphQL resolver call
  def create_post(%{title: title, body: body}, _resolution) do
    # Validation logic in resolver — bad
    if String.length(title) < 3 do
      {:error, "title too short"}
    else
      post = %__MODULE__{
        id: System.unique_integer([:positive]),
        title: title,
        body: body,
        published: false
      }
      {:ok, post}
    end
  end
end

defmodule AbsBadCtx.ResolverHeavyTest do
  use ExUnit.Case, async: true

  alias AbsBadCtx.Resolvers.Posts, as: Resolver

  # BAD: to test any logic, we must go through the resolver
  # There is no context module to test in isolation

  test "bad: testing validation requires calling the resolver" do
    # We must construct a fake resolution and call the resolver directly.
    # In a real app with Absinthe this would require Absinthe.run/3 or
    # a resolution struct, adding complexity and coupling to the GraphQL layer.
    assert {:error, "title too short"} =
             Resolver.create_post(%{title: "Hi", body: "body"}, %{})
  end

  test "bad: creates post — logic is not accessible from other callers" do
    # Any non-GraphQL caller (LiveView, REST, internal process) would have to
    # duplicate this logic because it's locked inside the resolver.
    assert {:ok, post} = Resolver.create_post(%{title: "Hello World", body: "body"}, %{})
    assert post.title == "Hello World"
  end

  test "bad: no context module exists to test the business rule directly" do
    # There is no MyApp.Posts.create_post/1 — the logic is only in the resolver.
    # This means:
    # - Cannot test edge cases without going through GraphQL
    # - Cannot reuse the validation from a Phoenix controller or LiveView
    # - Logic is invisible to documentation tools (HexDoc, etc.)
    assert true
  end
end
