---
id: ETC-ECTO-001
title: "Test changeset validations without the database"
category: ecto
severity: recommendation
summary: >
  Changeset validations such as validate_required, validate_format, and validate_length
  are pure functions — they operate on data structures and return results without any
  database interaction. Tests for these validations should use only Mix.install([:ecto])
  and never spin up a database.
principles:
  - purity-separation
applies_when:
  - "Testing validate_required, validate_format, validate_length, validate_inclusion, or validate_exclusion"
  - "Testing custom validate_change callbacks that inspect field values"
  - "Testing that a changeset correctly maps fields via cast/3"
  - "Any test that does not need to verify a database constraint"
related_rules:
  - ETC-ECTO-003
---

# Test changeset validations without the database

Changeset validation functions in Ecto are pure — they transform a `%Ecto.Changeset{}`
struct and return a new one. No database connection is required. Spinning up a Repo for
tests that only check validations is unnecessary overhead and conflates two distinct
concerns: data correctness and persistence.

## Problem

When developers write changeset tests against a real database they pay:

- Slower test startup (database connection pool, migrations)
- Coupling between validation logic and infrastructure
- Flakier tests that can fail for database reasons unrelated to the validation under test

The principle of purity separation says: test pure logic purely.

## Detection

- A test module that calls `Repo.insert/1` or `Repo.insert!/1` but only inspects
  `changeset.valid?` or `changeset.errors`
- A test that starts a Repo but never uses the returned struct from an insert

## Bad

```elixir
# Starts a database just to check a pure validation
defmodule MyApp.UserChangesetTest do
  use ExUnit.Case, async: true

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
  end

  test "requires email" do
    changeset = MyApp.User.changeset(%MyApp.User{}, %{name: "Alice"})
    refute changeset.valid?
    assert {:email, {"can't be blank", _}} = hd(changeset.errors)
  end
end
```

## Good

```elixir
# No Repo, no sandbox, just Ecto changeset logic
defmodule MyApp.UserChangesetTest do
  use ExUnit.Case, async: true

  defp changeset(attrs), do: MyApp.User.changeset(%MyApp.User{}, attrs)

  test "requires email" do
    cs = changeset(%{name: "Alice"})
    refute cs.valid?
    assert cs.errors[:email] != nil
  end

  test "valid with required fields" do
    cs = changeset(%{name: "Alice", email: "alice@example.com"})
    assert cs.valid?
  end
end
```

## When This Applies

- Any test that asserts on `changeset.valid?`, `changeset.errors`, or `changeset.changes`
  without needing the result of a database insert

## Further Reading

- [Ecto.Changeset docs](https://hexdocs.pm/ecto/Ecto.Changeset.html)
- ETC-ECTO-002 — for when you DO need a database (constraint testing)
