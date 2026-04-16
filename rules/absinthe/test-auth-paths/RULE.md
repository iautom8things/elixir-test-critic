---
id: ETC-ABS-003
title: "Test both authorized and unauthorized paths"
category: absinthe
severity: critical
summary: >
  Every protected query or mutation must have tests for: the authenticated
  happy path, unauthenticated access (no current_user in context), and
  wrong-role or wrong-user access. Missing authorization tests are the most
  dangerous gap in a GraphQL API test suite.
principles:
  - boundary-testing
  - public-interface
does_not_apply_when:
  - "Public queries/mutations that have no authorization requirements"
applies_when:
  - "Any query or mutation that checks current_user in the context"
  - "Any resolver that restricts access based on role or ownership"
  - "Any field that should be hidden from unauthenticated or unprivileged users"
related_rules:
  - ETC-ABS-002
  - ETC-MOCK-002
  - ETC-ABS-005
---

# Test both authorized and unauthorized paths

Authorization bugs in a GraphQL API are especially dangerous because:

- GraphQL introspection can reveal the full schema to anyone
- Mutations often have side effects (payments, deletions, privilege escalation)
- A missing authorization check can expose data to all users, not just one

Every resolver that enforces access control must be tested for all three paths:

1. **Authenticated happy path** — valid user with correct permissions succeeds
2. **Unauthenticated access** — no `current_user` in context is rejected
3. **Wrong role/wrong user** — user exists but lacks permission is rejected

## Problem

Tests that only cover the happy path leave the authorization boundary
completely unverified. An empty or nil `current_user` check that is absent
from the resolver will allow unauthenticated access without any test failing.

Similarly, testing only "admin can do X" without testing "regular user cannot
do X" leaves privilege escalation paths open.

## Detection

- A resolver that checks `context.current_user` but only has one test
- Mutations with no test using an empty context (`context: %{}`)
- No tests asserting on `errors` for a protected query

## Bad

```elixir
defmodule MyApp.AdminResolverTest do
  use MyApp.DataCase, async: true

  test "admin can delete post" do
    admin = insert(:user, role: :admin)
    post = insert(:post)

    # Only the happy path is tested — unauthorized paths are invisible
    assert {:ok, _deleted} =
             Absinthe.run(@delete_mutation, MyApp.Schema,
               variables: %{"id" => post.id},
               context: %{current_user: admin}
             )
  end
end
```

## Good

```elixir
defmodule MyApp.AdminResolverTest do
  use MyApp.DataCase, async: true

  @delete_mutation """
  mutation DeletePost($id: ID!) {
    deletePost(id: $id) { id }
  }
  """

  test "admin can delete any post" do
    admin = insert(:user, role: :admin)
    post = insert(:post)

    assert {:ok, %{data: %{"deletePost" => %{"id" => _}}}} =
             Absinthe.run(@delete_mutation, MyApp.Schema,
               variables: %{"id" => post.id},
               context: %{current_user: admin}
             )
  end

  test "unauthenticated user cannot delete post" do
    post = insert(:post)

    assert {:ok, %{errors: [%{message: message}]}} =
             Absinthe.run(@delete_mutation, MyApp.Schema,
               variables: %{"id" => post.id},
               context: %{}  # no current_user
             )

    assert message =~ "unauthorized"
  end

  test "regular user cannot delete another user's post" do
    user = insert(:user, role: :user)
    other_post = insert(:post)

    assert {:ok, %{errors: [%{message: message}]}} =
             Absinthe.run(@delete_mutation, MyApp.Schema,
               variables: %{"id" => other_post.id},
               context: %{current_user: user}
             )

    assert message =~ "unauthorized"
  end
end
```

## When This Applies

- Every resolver that calls `context.current_user` or checks a role
- Every mutation that modifies data on behalf of a specific user
- Every query that returns user-specific or role-gated data

## When This Does Not Apply

- Public queries/mutations that have no authorization requirements (e.g., `{ products { name } }`)

## Further Reading

- [Absinthe context and authentication](https://hexdocs.pm/absinthe/context-and-authentication.html)
- [Absinthe middleware for authorization](https://hexdocs.pm/absinthe/Absinthe.Middleware.html)
