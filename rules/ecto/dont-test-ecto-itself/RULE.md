---
id: ETC-ECTO-003
title: "Test your changeset function, not Ecto's validations"
category: ecto
severity: warning
summary: >
  Do not write tests that verify Ecto's built-in validation behaviour (e.g. that
  validate_required rejects nil). That is Ecto's responsibility, covered by Ecto's own
  test suite. Your tests should verify that YOUR changeset function calls the right
  validators on the right fields with the right options.
principles:
  - boundary-testing
applies_when:
  - "Writing tests for a module that defines a changeset/2 function"
  - "Testing that specific fields are validated"
  - "Testing that specific validation options are applied (e.g. min/max length)"
related_rules:
  - ETC-ECTO-001
---

# Test your changeset function, not Ecto's validations

The purpose of testing your changeset function is to verify the *contract* your application
enforces on its data — which fields are required, what format they must be in, what range
is acceptable. It is **not** to verify that `validate_required/2` rejects nil when given a
required field — that is tested by Ecto itself.

## Problem

Tests that are really testing Ecto's own correctness rather than your code:

1. Add zero confidence because they cannot fail unless Ecto is broken
2. Clutter the test suite with low-value cases
3. Mislead future readers into thinking the logic lives in your changeset when it lives in Ecto

## Detection

- A test that passes `nil` for a field and only asserts that an error exists — without
  also testing that YOUR changeset includes that field in its `required` list
- Multiple tests all saying "this field is blank → invalid" when you have 10+ required fields

## Bad

```elixir
# Tests Ecto, not your code
test "rejects nil email" do
  cs = User.changeset(%User{}, %{email: nil, name: "Alice"})
  refute cs.valid?
end

test "rejects nil name" do
  cs = User.changeset(%User{}, %{email: "a@b.com", name: nil})
  refute cs.valid?
end
# … repeated for every required field
```

These tests pass because Ecto works correctly, not because your changeset is correct.
If you accidentally removed `:name` from `validate_required/2`, *one* of these tests would
catch it — but only if you happen to test that exact field.

## Good

```elixir
# Tests YOUR changeset's contract
test "requires name and email" do
  cs = User.changeset(%User{}, %{})
  assert {:name, _} = List.keyfind(cs.errors, :name, 0)
  assert {:email, _} = List.keyfind(cs.errors, :email, 0)
end

test "accepts valid data" do
  cs = User.changeset(%User{}, %{name: "Alice", email: "alice@example.com"})
  assert cs.valid?
end

test "rejects email without @" do
  cs = User.changeset(%User{}, %{name: "Alice", email: "not-an-email"})
  refute cs.valid?
  assert cs.errors[:email] != nil
end
```

One test covers all required fields together. If you accidentally drop a field from
`validate_required`, it shows up immediately as a missing error.

## When This Applies

- Any test module that covers an Ecto changeset function

## Further Reading

- [Ecto.Changeset docs](https://hexdocs.pm/ecto/Ecto.Changeset.html)
- ETC-ECTO-001 — test validations without a database
- ETC-ECTO-004 — use errors_on/1 for cleaner assertions
