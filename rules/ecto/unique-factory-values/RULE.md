---
id: ETC-ECTO-005
title: "Use System.unique_integer for factory unique fields"
category: ecto
severity: warning
summary: >
  A factory with a hardcoded unique value (e.g. email: "user@test.com") fails with a
  unique constraint error the second time one test calls it. Across concurrent sandbox
  tests it makes them wait on each other's locks and can deadlock. Use
  System.unique_integer([:positive]) to generate a unique value per call.
principles:
  - async-default
  - honest-data
applies_when:
  - "Defining a factory or fixture function that inserts records with unique fields"
  - "Any helper that builds a User, Account, or other schema with a unique index"
  - "Test setup blocks that create database records used across multiple tests"
does_not_apply_when:
  - "The field has no unique index"
---

# Use System.unique_integer for factory unique fields

A factory that inserts the same hardcoded email every time breaks in two ways.

**Within one test.** A test that needs two users calls the factory twice. The
second insert hits the unique index and fails, every time. Callers work around it
by overriding the field, and the factory's default becomes a trap.

**Across concurrent tests.** With `async: true` and the SQL sandbox, each test
runs in its own transaction, so the second test does not get a constraint error.
It waits for the first test's transaction to end. Tests that share the value run
one at a time on that row, and two shared values taken in opposite orders can
deadlock (see ETC-ISO-002).

`System.unique_integer([:positive])` returns an integer that is unique within the
running VM, so every factory call gets its own value.

## Problem

```elixir
# DANGER: all async tests that call user_fixture() share "user@test.com"
def user_fixture(attrs \\ %{}) do
  {:ok, user} = Accounts.create_user(Map.merge(%{
    email: "user@test.com",  # ← hardcoded: a second call in one test fails
    password: "password123"
  }, attrs))
  user
end
```

A test that calls `user_fixture()` twice fails on the second call with a unique
constraint error on `email`. Two async tests that each call it once do not fail,
but one waits for the other.

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

- Fields with no unique index
- A factory that takes the unique value as a required argument, so every caller
  supplies its own

## Further Reading

- [System.unique_integer/1 docs](https://hexdocs.pm/elixir/System.html#unique_integer/1)
- [Ecto SQL Sandbox docs](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- ETC-ECTO-002 — constraint testing requires a real DB
- ETC-ECTO-009 — allow spawned processes to share sandbox connections
