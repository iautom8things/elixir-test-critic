---
id: ETC-ECTO-006
title: "Create test data through context functions"
category: ecto
severity: warning
summary: >
  Use your application's context functions (e.g. Accounts.create_user/1) rather than raw
  Repo.insert/1 to create test data. Context functions apply business rules, callbacks,
  and associations that raw inserts bypass, keeping your test data honest.
principles:
  - honest-data
  - boundary-testing
applies_when:
  - "Setting up test data in setup blocks or fixture functions"
  - "Creating related records (e.g. user + profile, post + author)"
  - "Any test where the behaviour under test depends on data created in a specific way"
---

# Create test data through context functions

Phoenix contexts (or equivalent service/domain modules) are the public API of your
application. They enforce business rules: password hashing, default values, association
creation, event emission. Bypassing them with raw `Repo.insert/1` in tests creates data
that could never exist in production, causing tests to pass against an impossible state.

## Problem

When you insert raw data directly into the repository:

1. Business rules applied in the context function are skipped (e.g. password hashing, defaults)
2. Side effects are bypassed (e.g. welcome emails, audit log entries)
3. Associated records that are always created together are missing
4. Tests pass against data that cannot exist in a running application

## Detection

- `Repo.insert/1` or `Repo.insert!/1` calls in test setup blocks or fixture functions
  for data that is normally created through a context function
- Missing associations in test data (e.g. a `Post` without an `author_id` even though
  `Posts.create_post/2` always requires an author)

## Bad

```elixir
setup do
  # Bypasses Accounts.create_user — skips password hashing, default role assignment
  {:ok, user} = Repo.insert(%User{email: "alice@example.com", name: "Alice"})
  %{user: user}
end
```

## Good

```elixir
setup do
  # Goes through the context — applies all business rules
  {:ok, user} = Accounts.create_user(%{
    email: "alice-#{System.unique_integer([:positive])}@example.com",
    name: "Alice",
    password: "secure_password_123"
  })
  %{user: user}
end
```

## When This Applies

- Setup blocks that create the primary entities under test
- Fixture/factory helpers used across multiple test modules

## Exceptions

- Tests specifically testing the schema or changeset layer (ECTO-001) — at that level,
  bypassing the context is intentional
- Performance-sensitive test suites where the context function is too slow and the
  business rules are irrelevant to the test (document the exception explicitly)

## Further Reading

- [Chris McCord — Phoenix Contexts guide](https://hexdocs.pm/phoenix/contexts.html)
- ETC-ECTO-005 — always use unique values in fixtures
