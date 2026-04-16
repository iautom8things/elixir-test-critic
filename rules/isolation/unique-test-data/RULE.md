---
id: ETC-ISO-002
title: "Generate unique values for constrained fields"
category: isolation
severity: critical
summary: >
  Use unique values for fields with uniqueness constraints (emails, usernames,
  slugs, external IDs) in each test. Hardcoded values shared across tests cause
  constraint violation errors when tests run concurrently or when the database
  is not fully reset between tests.
principles:
  - async-default
  - honest-data
applies_when:
  - "Tests that insert records into a database with uniqueness constraints"
  - "Tests that create data with unique identifiers (emails, usernames, API keys, slugs)"
  - "Tests using Ecto with SQL Sandbox in async mode"
does_not_apply_when:
  - "Tests run with async: false and uniqueness is not a database concern (e.g., in-memory only tests)"
---

# Generate unique values for constrained fields

When multiple tests insert records with the same hardcoded email, username, or other
unique-constrained field, they collide. In async mode this collision is a race; in
sequential mode it still occurs when the database is shared across tests without full
isolation (e.g., when using SQL Sandbox in manual mode with `allow` for concurrent
processes).

## Problem

Hardcoded test data creates two classes of failures:

1. **Concurrent collision**: Two async tests both try to insert `email: "alice@example.com"`.
   One succeeds, the other gets a constraint violation. The failure is non-deterministic —
   it depends on which test runs first.

2. **Sequential pollution**: Without full database rollback, the first test's data persists
   and the second test fails with a unique constraint error even in sequential mode.

The fix is to generate unique values per test. Common techniques:
- `System.unique_integer([:positive])` for numeric uniqueness
- Appending a unique integer to a base string: `"user_#{System.unique_integer([:positive])}@example.com"`

## Detection

- Hardcoded email, username, slug, or external ID strings in multiple tests in the same module
- `%{email: "test@example.com"}` appearing in more than one test or fixture
- Constraint violation errors (`{:error, changeset}` with `:unique_constraint` in tests)

## Bad

```elixir
describe "create/1" do
  test "creates a user" do
    assert {:ok, user} = Accounts.create(%{email: "alice@example.com"})
    assert user.email == "alice@example.com"
  end

  test "email is downcased on create" do
    # Same email — constraint violation if both tests run concurrently or sequentially
    assert {:ok, user} = Accounts.create(%{email: "alice@example.com"})
    assert user.email == "alice@example.com"
  end
end
```

## Good

```elixir
describe "create/1" do
  test "creates a user" do
    email = "alice_#{System.unique_integer([:positive])}@example.com"
    assert {:ok, user} = Accounts.create(%{email: email})
    assert user.email == email
  end

  test "email is downcased on create" do
    n = System.unique_integer([:positive])
    email = "Alice_#{n}@EXAMPLE.COM"
    assert {:ok, user} = Accounts.create(%{email: email})
    assert user.email == String.downcase(email)
  end
end
```

## When This Applies

- Database tests with uniqueness constraints on any field
- In-memory stores (ETS, GenServer state) with unique key requirements
- Any test where the same key being inserted twice would cause an error

## When This Does Not Apply

- Tests where async: false AND each test gets a full database rollback between runs —
  uniqueness is not a concern if the record never persists across test boundaries
- Testing the uniqueness constraint itself — you intentionally insert the same value
  twice to verify the constraint is enforced

## Further Reading

- [Ecto.Adapters.SQL.Sandbox](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [ExMachina — factory libraries for Elixir tests](https://github.com/thoughtbot/ex_machina)
