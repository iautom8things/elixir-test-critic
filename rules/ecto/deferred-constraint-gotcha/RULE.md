---
id: ETC-ECTO-010
title: "Force immediate constraints when testing deferrables"
category: ecto
severity: warning
summary: >
  Deferred constraints in PostgreSQL are only checked at transaction commit, not at the
  point of the offending statement. Tests that expect a constraint error mid-transaction
  will silently pass without catching the violation. Use SET CONSTRAINTS ALL IMMEDIATE
  to force evaluation, or restructure the test to commit and observe the error.
  Note: SQLite does not support deferred constraints; this rule is Postgres-specific.
principles:
  - boundary-testing
applies_when:
  - "Testing behaviour around DEFERRABLE INITIALLY DEFERRED constraints in PostgreSQL"
  - "Tests that expect a constraint error but the constraint is deferred"
  - "Integration tests for database schemas with deferred foreign key or unique constraints"
---

# Force immediate constraints when testing deferrables

PostgreSQL supports `DEFERRABLE INITIALLY DEFERRED` constraints, which means the database
only checks the constraint at the end of the transaction (at `COMMIT`), not when the
violating row is inserted. This is useful for operations like reordering records where
you temporarily violate a unique ordering constraint.

The problem for tests: if you insert a constraint-violating row inside a transaction and
expect an error at the `INSERT` statement, you won't get one. The test will pass the
INSERT, not observe an error, and your assertion will fail or — worse — you won't assert
at all and the test gives false confidence.

## Two solutions

**Option 1: SET CONSTRAINTS ALL IMMEDIATE**

Execute `SET CONSTRAINTS ALL IMMEDIATE` within the transaction to force all deferred
constraints to be checked immediately. This is useful when you want to test mid-transaction
constraint violations.

```sql
SET CONSTRAINTS ALL IMMEDIATE;
```

In Ecto:
```elixir
Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")
```

**Option 2: Commit the transaction**

Let the transaction commit (or roll back intentionally) and observe whether Postgres
returns a constraint error at commit time. With Ecto's `Repo.transaction/1`, a deferred
constraint violation causes `{:error, ...}` to be returned from the transaction.

## SQLite note

SQLite does not support deferred constraints. Constraint checking in SQLite always
happens immediately. The examples in this rule use SQLite to demonstrate immediate
constraint testing, which is analogous to how Postgres behaves after
`SET CONSTRAINTS ALL IMMEDIATE`. For production Postgres deferred constraint testing,
use `Repo.query!("SET CONSTRAINTS ALL IMMEDIATE")` as shown above.

## Detection

- Postgres schema has `DEFERRABLE INITIALLY DEFERRED` on a constraint
- A test inserts a row that violates a deferred constraint and checks for an error
  at the INSERT step (not at transaction commit)
- Tests pass but deferred constraint violations go undetected

## Bad (Postgres conceptual example)

```elixir
# POSTGRES ONLY — BAD: expects error at INSERT but constraint is deferred
test "rejects duplicate position" do
  :ok = Sandbox.checkout(Repo)
  Repo.insert!(%Item{position: 1})  # succeeds

  # Deferred unique on :position — no error here, error is deferred to commit
  assert {:error, _} = Repo.insert(%Item{position: 1})  # WRONG: {:ok, _} is returned
end
```

## Good (Postgres conceptual example)

```elixir
# POSTGRES ONLY — GOOD: force immediate checking
test "rejects duplicate position with immediate constraint" do
  :ok = Sandbox.checkout(Repo)
  Repo.insert!(%Item{position: 1})
  Repo.query!("SET CONSTRAINTS items_position_unique IMMEDIATE")

  assert {:error, changeset} = Repo.insert(%Item{position: 1})
  assert changeset.errors[:position] != nil
end
```

## Further Reading

- [PostgreSQL — Deferrable Constraints](https://www.postgresql.org/docs/current/sql-set-constraints.html)
- [PostgreSQL — CREATE TABLE constraint timing](https://www.postgresql.org/docs/current/sql-createtable.html)
- ETC-ECTO-002 — constraint testing requires real DB operations
