---
id: ETC-ECTO-003
title: "Test your changeset function, not Ecto's validations"
category: ecto
severity: warning
summary: >
  Test the changeset function your application defines, and assert on the
  specific error it produces. A test that builds its own changeset checks Ecto,
  not your code. A test that only refutes `valid?` passes for any error at all.
principles:
  - boundary-testing
applies_when:
  - "Writing tests for a module that defines a changeset/2 function"
  - "A test calls cast/3 or a validate_* function directly instead of the application's changeset function"
  - "A test asserts only that a changeset is invalid"
does_not_apply_when:
  - "A test calls the application's changeset function and asserts on a specific field's error, even if it covers one field per test"
related_rules:
  - ETC-ECTO-001
---

# Test your changeset function, not Ecto's validations

The purpose of testing a changeset function is to verify the contract your
application enforces on its data: which fields are required, what format they
must have, what range is acceptable. A test does that only if it calls your
function and checks which rule fired.

A test of one field at a time is fine. `User.changeset(%User{}, %{name: nil})`
followed by an assertion on the `:name` error fails the day someone removes
`:name` from `validate_required`. That is a test of your code.

## Problem

Two shapes look like changeset tests and protect nothing:

1. **The test builds its own changeset.** It pipes a struct through `cast/3`,
   `validate_required/2` or `check_constraint/3` itself and asserts on the
   result. It never calls the application's function, so it keeps passing when
   that function loses the validation. It can only fail if Ecto is broken.
2. **The test asserts only `refute changeset.valid?`.** Any error satisfies it.
   A test named "rejects nil name" passes because a different required field
   was also missing from its input, and keeps passing after `:name` stops
   being required.

## Detection

- `cast/3`, `validate_*` or `*_constraint` called inside a test body on a
  changeset the test then asserts on
- `refute changeset.valid?` (or `assert {:error, _}`) with no assertion on which
  field or message failed

Do not flag per-field tests that call the application's changeset function and
assert on that field's error.

## Bad

```elixir
# Never calls User.changeset/2. Tests Ecto.
test "name is required" do
  changeset =
    %User{}
    |> cast(%{email: "alice@example.com"}, [:name, :email])
    |> validate_required([:name])

  assert "can't be blank" in errors_on(changeset).name
end

# Passes for any error. Here :email is missing too.
test "rejects nil name" do
  changeset = User.changeset(%User{}, %{name: nil})
  refute changeset.valid?
end
```

## Good

```elixir
test "requires name and email" do
  changeset = User.changeset(%User{}, %{})

  assert "can't be blank" in errors_on(changeset).name
  assert "can't be blank" in errors_on(changeset).email
end

test "rejects an email without @" do
  changeset = User.changeset(%User{}, %{name: "Alice", email: "no-at-sign"})

  assert "has invalid format" in errors_on(changeset).email
end

test "accepts valid data" do
  changeset = User.changeset(%User{}, %{name: "Alice", email: "alice@example.com"})

  assert changeset.valid?
end
```

Each test calls `User.changeset/2` and names the error it expects. Remove a
validation and the matching assertion fails.

## When This Applies

- Any test module that covers an Ecto changeset function

## Further Reading

- [Ecto.Changeset docs](https://hexdocs.pm/ecto/Ecto.Changeset.html)
- ETC-ECTO-001 — test validations without a database
- ETC-ECTO-004 — use errors_on/1 for cleaner assertions
