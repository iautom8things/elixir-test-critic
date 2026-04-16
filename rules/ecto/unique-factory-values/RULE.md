---
id: ETC-ECTO-005
title: "Use System.unique_integer for factory unique fields"
category: ecto
severity: critical
summary: >
  Hardcoded unique values in test factories (e.g. email: "user@test.com") cause unique
  constraint violations when tests run concurrently. Use System.unique_integer([:positive])
  to generate unique values per test invocation.
principles:
  - async-default
  - honest-data
applies_when:
  - "Defining a factory or fixture function that inserts records with unique fields"
  - "Any helper that builds a User, Account, or other schema with a unique index"
  - "Test setup blocks that create database records used across multiple tests"
does_not_apply_when:
  - "Tests run with async: false and uniqueness is guaranteed by other means"
---

# Use System.unique_integer for factory unique fields

When tests run concurrently (`async: true` with Ecto SQL Sandbox), multiple tests execute
at the same time. If every test's factory function inserts a row with the same hardcoded
email address, the second test to run will hit a unique constraint violation on the email
column — not because the test logic is wrong, but because the test data is shared.

`System.unique_integer([:positive])` returns a monotonically increasing integer that is
unique per BEAM node invocation, making it safe for async test data generation.

## Problem

```elixir
# DANGER: all async tests that call user_fixture() share "user@test.com"
def user_fixture(attrs \\ %{}) do
  {:ok, user} = Accounts.create_user(Map.merge(%{
    email: "user@test.com",  # ← hardcoded, will collide in async tests
    password: "password123"
  }, attrs))
  user
end
```

When two async tests call `user_fixture()` simultaneously, the second `create_user` call
fails with a unique constraint violation on the `email` column.

## Detection

- Factory or fixture functions with literal string values for fields covered by a
  `unique_index` or `unique_constraint`
- Hardcoded emails, usernames, slugs, or other unique identifiers in test helpers

## Bad

```elixir
def user_fixture do
  Repo.insert!(%User{email: "test@example.com", name: "Test User"})
end
```

## Good

```elixir
def user_fixture(attrs \\ %{}) do
  n = System.unique_integer([:positive])
  defaults = %{
    email: "user-#{n}@example.com",
    name: "User #{n}"
  }
  Repo.insert!(User.changeset(%User{}, Map.merge(defaults, attrs)))
end
```

## When This Applies

- All factory/fixture functions that create records with unique-indexed fields
- Especially important when using `async: true` with `Ecto.Adapters.SQL.Sandbox`

## When This Does Not Apply

- Tests run with `async: false` and uniqueness is guaranteed by other means
  (e.g., full database rollback between tests, no parallel execution)

## Further Reading

- [System.unique_integer/1 docs](https://hexdocs.pm/elixir/System.html#unique_integer/1)
- [Ecto SQL Sandbox docs](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- ETC-ECTO-002 — constraint testing requires a real DB
- ETC-ECTO-009 — allow spawned processes to share sandbox connections
