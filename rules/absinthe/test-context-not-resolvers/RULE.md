---
id: ETC-ABS-001
title: "Test context functions, not resolvers"
category: absinthe
severity: recommendation
summary: >
  Focus the bulk of your test effort on context module functions (pure business
  logic), not on GraphQL resolver functions. Resolvers should be thin
  pass-throughs that delegate immediately to context functions. Testing the
  context directly is faster, simpler, and gives better coverage.
principles:
  - purity-separation
  - thin-processes
applies_when:
  - "Writing tests for GraphQL resolvers that contain business logic"
  - "A resolver does more than call one context function and return its result"
  - "Deciding where to locate test coverage for a new Absinthe query or mutation"
related_rules:
  - ETC-OTP-001
  - ETC-BWAY-004
  - ETC-MOCK-009
---

# Test context functions, not resolvers

Absinthe co-creator benwilson512 recommends keeping resolvers as thin
pass-throughs. A resolver's only job is to:

1. Extract arguments from the Absinthe resolution struct
2. Call one context function
3. Return `{:ok, result}` or `{:error, reason}`

When resolvers are thin, all the interesting logic lives in context modules,
which are plain Elixir modules that are easy to test in isolation without
booting a GraphQL schema.

## Problem

Putting business logic in resolvers has two costs:

- **Testing requires the full GraphQL layer.** To test the logic, you must
  construct Absinthe resolution structs or execute a full query string through
  `Absinthe.run/3`. Both are heavier than calling `MyApp.Posts.create_post/1`.
- **Logic is hidden inside the resolver.** Context functions are documented,
  typed, and reusable from other callers (REST endpoints, internal processes,
  LiveView). Resolver logic is only reachable through GraphQL.

## Detection

- Resolver functions longer than ~5 lines of business logic
- Test modules that only use `Absinthe.run/3` but never call context functions
  directly
- No test module for the corresponding `MyApp.SomeContext` module

## Bad

```elixir
# resolver — contains business logic that should be in the context
def create_post(%{title: title, body: body}, _resolution) do
  if String.length(title) < 3 do
    {:error, "title too short"}
  else
    %Post{}
    |> Post.changeset(%{title: title, body: body, published: false})
    |> Repo.insert()
    |> case do
      {:ok, post} -> {:ok, post}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end
end

# test — must go through GraphQL to reach the validation logic
test "rejects short titles" do
  query = """
  mutation { createPost(title: "Hi", body: "body") { id } }
  """
  assert {:ok, %{errors: [%{message: msg}]}} = Absinthe.run(query, MySchema)
  assert msg =~ "title too short"
end
```

## Good

```elixir
# context — pure business logic, easy to test directly
defmodule MyApp.Posts do
  def create_post(%{title: title} = attrs) when byte_size(title) < 3 do
    {:error, :title_too_short}
  end
  def create_post(attrs) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end
end

# resolver — thin pass-through
def create_post(%{title: title, body: body}, _resolution) do
  MyApp.Posts.create_post(%{title: title, body: body})
end

# test — fast, direct, no GraphQL overhead
test "rejects titles shorter than 3 characters" do
  assert {:error, :title_too_short} = Posts.create_post(%{title: "Hi", body: "body"})
end

test "creates a post with valid attributes" do
  assert {:ok, %Post{title: "Hello"}} =
           Posts.create_post(%{title: "Hello", body: "body"})
end
```

## When This Applies

- Any project using Absinthe with context modules (the standard Phoenix
  architecture)
- Resolvers that contain validation, transformation, or conditional logic

## When This Does Not Apply

- Resolvers whose only job is to return a static value or relay a preloaded
  association — no context function is warranted for trivial field resolution
- Integration tests that intentionally exercise the full GraphQL stack to verify
  the resolver wiring is correct

## Further Reading

- [benwilson512 on resolver design](https://github.com/absinthe-graphql/absinthe/issues/1117)
- [Absinthe context and authentication guide](https://hexdocs.pm/absinthe/context-and-authentication.html)
