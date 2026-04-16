---
id: ETC-ABS-005
title: "Store GraphQL queries as module attributes"
category: absinthe
severity: style
summary: >
  Define GraphQL query strings as `@query` or `@mutation` module attributes at
  the top of the test module rather than inline as string literals inside each
  test body. This improves readability, enables reuse across multiple tests in
  the same module, and makes query changes a single edit.
principles:
  - public-interface
applies_when:
  - "Any test module that runs more than one GraphQL query against the same schema"
  - "Mutation tests with multiple cases (success, validation error, auth error)"
  - "Test modules where the same query document is used across multiple tests"
related_rules:
  - ETC-ABS-002
  - ETC-ABS-003
---

# Store GraphQL queries as module attributes

GraphQL query strings repeated inline in every test body create maintenance
problems and make the test file harder to read. Defining them as module
attributes follows the same principle as named constants: the name documents
intent and a single edit propagates everywhere.

## Problem

Inline query strings:

- Are repeated when multiple tests use the same query
- Bury the query inside test logic, making it harder to see what is being
  tested at a glance
- Must be updated in multiple places when the schema changes a field name or
  argument
- Cannot be named to express their purpose

## Detection

- The same query string literal appearing in two or more tests in the same module
- Query strings defined inside `test` blocks rather than at module level

## Bad

```elixir
defmodule MyApp.PostsSchemaTest do
  use MyApp.DataCase, async: true

  test "returns post title" do
    post = insert(:post, title: "Hello")

    # Query string inline in test body
    assert {:ok, %{data: %{"post" => %{"title" => "Hello"}}}} =
             Absinthe.run(
               "query GetPost($id: ID!) { post(id: $id) { title } }",
               MyApp.Schema,
               variables: %{"id" => post.id}
             )
  end

  test "returns post body" do
    post = insert(:post, body: "World")

    # Same query duplicated — must update in two places if schema changes
    assert {:ok, %{data: %{"post" => %{"body" => "World"}}}} =
             Absinthe.run(
               "query GetPost($id: ID!) { post(id: $id) { body } }",
               MyApp.Schema,
               variables: %{"id" => post.id}
             )
  end
end
```

## Good

```elixir
defmodule MyApp.PostsSchemaTest do
  use MyApp.DataCase, async: true

  # Query defined once, named for intent, reused across tests
  @post_query """
  query GetPost($id: ID!) {
    post(id: $id) {
      id
      title
      body
    }
  }
  """

  @create_post_mutation """
  mutation CreatePost($title: String!, $body: String!) {
    createPost(title: $title, body: $body) {
      id
      title
    }
  }
  """

  test "returns post title" do
    post = insert(:post, title: "Hello")

    assert {:ok, %{data: %{"post" => %{"title" => "Hello"}}}} =
             Absinthe.run(@post_query, MyApp.Schema,
               variables: %{"id" => post.id}
             )
  end

  test "returns post body" do
    post = insert(:post, body: "World")

    assert {:ok, %{data: %{"post" => %{"body" => "World"}}}} =
             Absinthe.run(@post_query, MyApp.Schema,
               variables: %{"id" => post.id}
             )
  end

  test "creates a post" do
    assert {:ok, %{data: %{"createPost" => %{"title" => "New"}}}} =
             Absinthe.run(@create_post_mutation, MyApp.Schema,
               variables: %{"title" => "New", "body" => "Body text"}
             )
  end
end
```

## When This Applies

- Any test module with more than one test using GraphQL queries
- Test modules using both a query and its error/auth variants

## When This Does Not Apply

- Test modules with exactly one test and one query — inline is acceptable
- Helper modules that construct query strings dynamically based on test
  parameters

## Further Reading

- [Elixir module attributes](https://hexdocs.pm/elixir/Module.html#module-module-attributes)
- [Absinthe testing guide](https://hexdocs.pm/absinthe/testing.html)
