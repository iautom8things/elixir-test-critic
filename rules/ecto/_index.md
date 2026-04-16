---
category: ecto
title: "Ecto Rules"
---

# Ecto Rules

Rules for testing Ecto schemas, changesets, queries, constraints, and transactions.
These rules draw on the principles of purity separation, boundary testing, and honest data.

## Quick Reference

| ID | Slug | Title | Severity |
|----|------|-------|----------|
| ETC-ECTO-001 | changeset-without-db | Test changeset validations without the database | recommendation |
| ETC-ECTO-002 | constraint-needs-db | Test constraint violations with actual DB operations | recommendation |
| ETC-ECTO-003 | dont-test-ecto-itself | Test your changeset function, not Ecto's validations | warning |
| ETC-ECTO-004 | use-errors-on-helper | Use errors_on/1 helper for changeset error assertions | style |
| ETC-ECTO-005 | unique-factory-values | Use System.unique_integer for factory unique fields | critical |
| ETC-ECTO-006 | context-functions-for-test-data | Create test data through context functions | warning |
| ETC-ECTO-007 | multi-unit-test | Unit test Ecto.Multi with to_list without DB | recommendation |
| ETC-ECTO-009 | allow-for-spawned-processes | Use Sandbox.allow for spawned process DB access | warning |
| ETC-ECTO-010 | deferred-constraint-gotcha | Force immediate constraints when testing deferrables | warning |

## Guiding Principles

### Pure vs. side-effecting

Ecto is split into two libraries for a reason: `ecto` (pure changesets and schemas) and
`ecto_sql` (database connectivity). Mirror this split in your tests:

- **No database needed**: changeset validations, Multi structure, schema casting
  → `Mix.install([:ecto])`
- **Database required**: constraint violations, queries, transactions
  → `Mix.install([:ecto_sql, :ecto_sqlite3])` + `_support/db.exs`

Rules ETC-ECTO-001 and ETC-ECTO-007 are the pure side.
Rules ETC-ECTO-002, ETC-ECTO-005, ETC-ECTO-006, ETC-ECTO-009, ETC-ECTO-010 require a DB.

### Test your code, not Ecto

ETC-ECTO-003 and ETC-ECTO-004 address a common overfit: writing tests that verify Ecto's
own validation logic rather than your changeset's contract. Test that YOUR changeset
requires the right fields, not that `validate_required` rejects nil.

### Async safety

ETC-ECTO-005 (unique factory values) and ETC-ECTO-009 (Sandbox.allow) are the two most
common causes of flaky async Ecto tests. Both are preventable with small, disciplined
conventions in your test helpers.

## Rule Details

### ETC-ECTO-001 — changeset-without-db

Changeset validations (`validate_required`, `validate_format`, `validate_length`) are pure
functions returning a `%Ecto.Changeset{}` struct. Tests for these functions do not need
a Repo or database connection. Use only `Mix.install([:ecto])`.

### ETC-ECTO-002 — constraint-needs-db

`unique_constraint/2` and `foreign_key_constraint/2` are metadata annotations on a
changeset struct — they tell Ecto how to translate a database error. The constraint only
fires when you actually insert or update against the database. Testing constraints without
a DB insert produces a test that can never catch violations.

### ETC-ECTO-003 — dont-test-ecto-itself

Your changeset test should verify that your function calls `validate_required` on the
correct set of fields — not that `validate_required` works correctly. Test the contract
of your function, not the implementation of the library.

### ETC-ECTO-004 — use-errors-on-helper

Ecto stores errors as `[{field, {message, opts}}]`. Pattern matching this directly is
fragile and verbose. A `errors_on/1` helper using `Ecto.Changeset.traverse_errors/2`
normalises errors to `%{field => [message]}`, producing readable and stable assertions.

### ETC-ECTO-005 — unique-factory-values

Hardcoded unique field values in factories (emails, usernames, slugs) cause unique
constraint violations when two async tests call the same factory simultaneously. Use
`System.unique_integer([:positive])` in factory defaults. This is a `critical` rule
because the failure mode is a flaky test suite that becomes unreliable in CI.

### ETC-ECTO-006 — context-functions-for-test-data

Your Phoenix contexts (or domain service modules) are the public API of your application.
They apply business rules, defaults, and side effects. Raw `Repo.insert` in test setup
bypasses all of this, producing test data that cannot exist in production. Use context
functions to create test data.

### ETC-ECTO-007 — multi-unit-test

`Ecto.Multi.to_list/1` returns the pipeline's operations as data without executing them.
Use this to unit test the structure of your Multi (which named operations exist, in what
order) without spinning up a database.

### ETC-ECTO-009 — allow-for-spawned-processes

The Ecto SQL Sandbox grants database access to the test process only. Any child process
(Task, GenServer, Agent) that makes Repo calls will raise `DBConnection.OwnershipError`
unless you call `Ecto.Adapters.SQL.Sandbox.allow/3` to share ownership.

### ETC-ECTO-010 — deferred-constraint-gotcha

PostgreSQL `DEFERRABLE INITIALLY DEFERRED` constraints are only checked at transaction
commit, not at INSERT time. A test that expects a constraint error mid-transaction will
be silently wrong. Use `SET CONSTRAINTS ALL IMMEDIATE` to force immediate evaluation, or
test at transaction commit. SQLite always checks constraints immediately; this rule is
Postgres-specific.
