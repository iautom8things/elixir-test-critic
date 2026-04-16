---
id: ETC-ECTO-002
title: "Test constraint violations with actual DB operations"
category: ecto
severity: recommendation
summary: >
  Ecto constraint helpers (unique_constraint, foreign_key_constraint, check_constraint)
  only produce errors when the changeset is actually inserted or updated against a real
  database. Asserting on constraint errors without performing a DB operation will always
  produce a false-passing test.
principles:
  - boundary-testing
applies_when:
  - "Testing unique_constraint on a field"
  - "Testing foreign_key_constraint"
  - "Testing check_constraint"
  - "Testing no_assoc_constraint or assoc_constraint"
  - "Any test that verifies database-level constraint violation error messages"
---

# Test constraint violations with actual DB operations

Ecto's `unique_constraint/2`, `foreign_key_constraint/2`, and related helpers annotate a
changeset with metadata that tells Ecto how to translate a database error into a changeset
error. **They do not validate anything themselves.** The constraint only fires when the
database rejects the operation.

A test that builds a changeset with `unique_constraint(:email)` and then checks
`changeset.errors` without inserting into the database will see no errors — the changeset
is valid until the database says otherwise.

## Problem

```elixir
# This test always passes, regardless of whether unique_constraint is correct
test "rejects duplicate email" do
  changeset =
    User.changeset(%User{}, %{email: "x@x.com"})
  # unique_constraint is set on the changeset, but no insert happened
  # changeset.errors is always [] here — this test is meaningless
  assert changeset.errors[:email] != nil  # always fails, or always passes if you flip it
end
```

## Detection

- A test uses `unique_constraint` or `foreign_key_constraint` in a changeset function
- The test inspects `changeset.errors` without calling `Repo.insert/1`

## Bad

```elixir
test "rejects duplicate email without DB" do
  # Building the changeset does NOT fire the constraint
  changeset = User.changeset(%User{}, %{email: "dup@test.com"})
  # This will always be empty — no DB operation occurred
  assert changeset.errors[:email] != nil
end
```

## Good

```elixir
test "rejects duplicate email via DB constraint" do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
  email = "dup-#{System.unique_integer()}@test.com"

  {:ok, _} = Repo.insert(User.changeset(%User{}, %{email: email}))

  {:error, changeset} = Repo.insert(User.changeset(%User{}, %{email: email}))
  assert changeset.errors[:email] != nil
end
```

## When This Applies

- Any test verifying that the database rejects duplicate rows, foreign-key violations,
  or check constraint failures

## Further Reading

- [Ecto.Changeset — Constraints](https://hexdocs.pm/ecto/Ecto.Changeset.html#module-constraints-and-validations)
- ETC-ECTO-001 — for pure validation tests that don't need a database
- ETC-ECTO-005 — use unique values in factory data to avoid cross-test constraint collisions
