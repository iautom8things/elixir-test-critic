---
id: ETC-ECTO-007
title: "Unit test Ecto.Multi with to_list without DB"
category: ecto
severity: recommendation
summary: >
  Ecto.Multi.to_list/1 returns the list of operations in a Multi pipeline without
  executing them. Use this to unit test the structure of your Multi — which operations
  are present, in what order, and with what names — without requiring a database.
principles:
  - purity-separation
applies_when:
  - "Testing a function that builds and returns an Ecto.Multi"
  - "Verifying that specific named operations are included in a pipeline"
  - "Testing the ordering of Multi operations without executing them"
  - "Testing helper functions that compose Multi pipelines"
---

# Unit test Ecto.Multi with to_list without DB

`Ecto.Multi` builds a description of a series of database operations. The struct itself
is data — it can be inspected, composed, and tested without a database. `Ecto.Multi.to_list/1`
exposes the operations as a list of `{name, operation}` tuples, enabling lightweight unit
tests of your pipeline's structure.

This is the purity separation principle applied to the database layer: separate the
*description* of what to do from the *execution* of doing it.

## Problem

Developers often resort to full integration tests with a real database to verify that a
Multi pipeline includes the right steps. This is slow and couples structural tests to
infrastructure.

## Detection

- A test calls `Repo.transaction(build_multi(...))` and only checks side effects that
  could have been verified by inspecting the Multi structure
- Functions that return `Ecto.Multi` are only tested end-to-end, never structurally

## Bad

```elixir
# Executes the Multi against a real DB just to check it "worked"
test "creates user and audit log" do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  {:ok, result} = Repo.transaction(MyApp.Accounts.register_user_multi(%{email: "a@b.com"}))
  assert Map.has_key?(result, :user)
  assert Map.has_key?(result, :audit_log)
end
```

## Good

```elixir
# Checks structure without DB
test "register_user_multi includes user and audit_log operations" do
  multi = MyApp.Accounts.register_user_multi(%{email: "a@b.com"})
  names = multi |> Ecto.Multi.to_list() |> Keyword.keys()
  assert :user in names
  assert :audit_log in names
end
```

Combine with an integration test that runs the transaction for end-to-end confidence.

## When This Applies

- Functions that construct and return an `Ecto.Multi` for the caller to transact
- Helper functions that merge or compose Multi pipelines

## Further Reading

- [Ecto.Multi.to_list/1 docs](https://hexdocs.pm/ecto/Ecto.Multi.html#to_list/1)
- [Ecto.Multi docs](https://hexdocs.pm/ecto/Ecto.Multi.html)
