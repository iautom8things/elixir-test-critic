# EXPECTED: passes
# BAD PRACTICE: Using HTTP round-trips for every schema test. This couples
# tests to the HTTP transport layer and adds unnecessary overhead when the
# goal is to test resolver logic, not Plug middleware.
Mix.install([])

ExUnit.start(autorun: true)

# Simulated HTTP layer (models ConnCase behaviour)
defmodule AbsRunBad.HttpLayer do
  @posts %{
    "1" => %{"title" => "Hello World"},
    "2" => %{"title" => "Draft"}
  }

  def post_graphql("get_post", %{"id" => id}, _headers) do
    case Map.get(@posts, id) do
      nil -> %{status: 200, body: %{"errors" => [%{"message" => "not found"}]}}
      post -> %{status: 200, body: %{"data" => %{"post" => post}}}
    end
  end

  def post_graphql("get_posts", _vars, _headers) do
    %{status: 200, body: %{"data" => %{"posts" => Map.values(@posts)}}}
  end
end

defmodule AbsRunBad.EverythingThroughHttpTest do
  use ExUnit.Case, async: true

  alias AbsRunBad.HttpLayer

  # BAD: every test goes through the HTTP layer even when we only care about
  # resolver output. In a real app this means JSON encoding/decoding and full
  # Plug pipeline overhead on every assertion.

  test "bad: uses HTTP to test basic query output — should use Absinthe.run/3" do
    # This should be: Absinthe.run(@query, Schema, context: %{current_user: user})
    # Instead we pay HTTP overhead just to check a field value.
    response = HttpLayer.post_graphql("get_post", %{"id" => "1"}, %{})
    assert response.status == 200
    assert response.body["data"]["post"]["title"] == "Hello World"
  end

  test "bad: uses HTTP to test error message — couples to JSON error format" do
    # This should be: assert {:ok, %{errors: [...]}} = Absinthe.run(...)
    # Instead we're asserting on the HTTP-encoded JSON error format,
    # which breaks if the error formatting middleware changes.
    response = HttpLayer.post_graphql("get_post", %{"id" => "999"}, %{})
    assert response.body["errors"] != nil
    assert hd(response.body["errors"])["message"] == "not found"
  end

  test "bad: uses HTTP to test list query — no HTTP-specific logic here" do
    # Testing the list shape doesn't require HTTP. Absinthe.run/3 would be
    # faster and avoid coupling to the HTTP transport format.
    response = HttpLayer.post_graphql("get_posts", %{}, %{})
    posts = response.body["data"]["posts"]
    assert length(posts) == 2
  end
end
