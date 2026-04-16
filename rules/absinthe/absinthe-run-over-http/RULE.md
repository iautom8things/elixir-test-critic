---
id: ETC-ABS-002
title: "Use Absinthe.run/3 for schema tests, HTTP for integration"
category: absinthe
severity: recommendation
summary: >
  Use `Absinthe.run/3` (or `Absinthe.run!/3`) when testing query logic,
  permissions, field resolution, and error handling. Reserve HTTP/ConnCase
  tests for verifying the full request pipeline — auth headers, Plug
  middleware, and JSON encoding. `Absinthe.run/3` is faster and requires no
  HTTP overhead.
principles:
  - boundary-testing
  - purity-separation
applies_when:
  - "Testing that a query returns specific fields or data shapes"
  - "Testing permission/authorization logic at the resolver level"
  - "Testing error messages or error types returned by mutations"
  - "Testing context values passed into resolvers"
related_rules:
  - ETC-ABS-003
  - ETC-PHX-001
  - ETC-MOCK-008
  - ETC-ABS-004
  - ETC-ABS-005
---

# Use Absinthe.run/3 for schema tests, HTTP for integration

There are two levels at which you can test a GraphQL API in Elixir:

1. **`Absinthe.run/3`** — executes a query document directly against a schema
   in-process, with no HTTP round-trip.
2. **HTTP/ConnCase** — sends the query via a full Plug/Phoenix HTTP request,
   exercising auth headers, JSON encoding, error formatting, and the entire
   middleware stack.

Most schema logic — resolver behaviour, data shapes, error types, context
injection — is best tested with `Absinthe.run/3`. HTTP tests should be
reserved for the integration layer.

## Problem

Using `post(conn, "/graphql", ...)` for every query test:

- Adds HTTP, JSON encoding/decoding, and Plug middleware overhead for every
  assertion
- Couples tests to the HTTP format of error messages rather than the Absinthe
  error model
- Makes it harder to inject custom context values (e.g., a test user) compared
  to `Absinthe.run/3`'s third argument

## Detection

- Test modules using `ConnCase` to call the GraphQL endpoint for every test,
  including tests that only care about schema output
- No tests using `Absinthe.run/3` or `Absinthe.run!/3` in the project

## Bad

```elixir
# Every test goes through HTTP — slow and over-coupled to the transport layer
defmodule MyAppWeb.PostsApiTest do
  use MyAppWeb.ConnCase, async: true

  test "returns post by id", %{conn: conn} do
    post = insert(:post, title: "Hello")

    # Full HTTP round-trip just to check query output
    conn =
      post(conn, "/api", %{
        query: "{ post(id: #{post.id}) { title } }"
      })

    assert json_response(conn, 200)["data"]["post"]["title"] == "Hello"
  end
end
```

## Good

```elixir
# Schema logic tested directly — fast, no HTTP
defmodule MyApp.PostsSchemaTest do
  use MyApp.DataCase, async: true

  @query """
  query GetPost($id: ID!) {
    post(id: $id) { title }
  }
  """

  test "returns post by id" do
    post = insert(:post, title: "Hello")

    assert {:ok, %{data: %{"post" => %{"title" => "Hello"}}}} =
             Absinthe.run(@query, MyApp.Schema,
               variables: %{"id" => post.id},
               context: %{current_user: insert(:user)}
             )
  end
end

# Full HTTP tested only for transport-level concerns
defmodule MyAppWeb.GraphQLPipelineTest do
  use MyAppWeb.ConnCase, async: true

  test "requires Authorization header", %{conn: conn} do
    conn = post(conn, "/api", %{query: "{ me { email } }"})
    assert json_response(conn, 200)["errors"] != nil
  end
end
```

## When This Applies

- Testing resolver output, field selection, argument handling
- Testing resolver-level authorization/context logic
- Testing error shapes and messages from Absinthe

## When This Does Not Apply

- Testing that the HTTP endpoint returns the correct status code
- Testing auth header validation in Plug middleware
- Testing JSON encoding of custom scalars or error formatting configured in
  the Plug pipeline
- End-to-end smoke tests that must go through the full stack

## Further Reading

- [Absinthe.run/3 documentation](https://hexdocs.pm/absinthe/Absinthe.html#run/3)
- [Absinthe testing guide](https://hexdocs.pm/absinthe/testing.html)
