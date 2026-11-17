---
id: ETC-ISO-002
title: "Generate unique values for constrained fields"
category: isolation
severity: warning
summary: >
  Use unique values for fields with uniqueness constraints (emails, usernames,
  slugs, external IDs) in each test. Under the SQL sandbox, two concurrent tests
  that insert the same value do not get a constraint error: one waits on the
  other's lock, which slows the suite and can deadlock. Outside a sandbox
  transaction, the same value is a real constraint violation.
principles:
  - async-default
  - honest-data
applies_when:
  - "Async tests that insert rows with unique-constrained fields through the SQL sandbox"
  - "Data inserted outside a per-test transaction: setup_all, seeds, automatic sandbox mode, a second database or service"
  - "In-memory stores (ETS, GenServer state) keyed by a value several tests reuse"
does_not_apply_when:
  - "The test is about the uniqueness constraint and inserts the same value twice on purpose"
  - "A value is unique only within a scope (per tenant, per parent) and each test creates its own scope"
---

# Generate unique values for constrained fields

When multiple tests insert records with the same hardcoded email, username, or
other unique-constrained field, they contend for the same unique index entry.
What happens next depends on whether each test runs inside its own sandbox
transaction.

## Problem

**Inside the SQL sandbox (the usual case).** Each test runs in a transaction that
is rolled back. When a second test inserts a value the first has already
inserted, the database makes the second wait for the first transaction to end.
The first rolls back, and the second insert then succeeds. So there is no
constraint error. The cost is different:

1. **Lock waits.** Tests that share a value run one after another on that row,
   so an `async: true` suite gets slower without any failure to point at.
2. **Deadlocks.** If two tests each hold a lock the other needs, such as two
   shared values inserted in opposite orders, the database kills one of them.
   That failure is intermittent. Ecto's sandbox documentation describes both.

**Outside a sandbox transaction.** The same value is a real unique violation,
and an order-dependent one, when the data outlives the test:

- rows inserted in `setup_all`, seeds, or migrations
- suites or helpers running in automatic sandbox mode (see ETC-ISO-004)
- a second database, an external service, or an in-memory store keyed by the value
- two inserts of the same hardcoded value inside one test, for example through
  a factory with a fixed default (see ETC-ECTO-005)

The fix is the same in every case: generate a unique value per test.

- `System.unique_integer([:positive])` for numeric uniqueness
- Appending a unique integer to a base string: `"user_#{System.unique_integer([:positive])}@example.com"`

## Detection

- The same email, username, slug, or external ID literal in several async tests
  that each insert it
- A hardcoded unique value inserted in `setup_all` or shared setup
- A deadlock or lock-timeout error from the database in an async suite
- A unique-constraint error on data the failing test did not create

Before reporting, confirm the field has a unique index. A repeated literal in a
column with no unique constraint is not a finding. Do not describe the outcome
as a constraint violation when each test runs in its own sandbox transaction.

## Bad

```elixir
describe "create/1" do
  test "creates a user" do
    assert {:ok, user} = Accounts.create(%{email: "alice@example.com"})
    assert user.email == "alice@example.com"
  end

  test "email is downcased on create" do
    # Same email as the test above. Run concurrently, one waits on the other's
    # row lock. If the data outlived the test, this would be a unique violation.
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

- Async database tests that insert rows with a unique index on any field
- Data created outside a per-test transaction
- In-memory stores (ETS, GenServer state) with unique key requirements

## When This Does Not Apply

- Testing the uniqueness constraint itself — you intentionally insert the same value
  twice to verify the constraint is enforced
- A value that is unique only within a scope each test creates for itself
- Columns with no unique index

## Further Reading

- [Ecto.Adapters.SQL.Sandbox: deadlocks](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#module-database-locks-and-deadlocks)
- [ExMachina — factory libraries for Elixir tests](https://github.com/thoughtbot/ex_machina)
