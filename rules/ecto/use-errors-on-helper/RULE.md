---
id: ETC-ECTO-004
title: "Use errors_on/1 helper for changeset error assertions"
category: ecto
severity: style
summary: >
  Instead of pattern matching on changeset.errors (a keyword list of tuples), define an
  errors_on/1 helper that converts errors to a plain map of field => [message strings].
  This makes assertions readable and decoupled from Ecto's internal tuple format.
principles:
  - public-interface
applies_when:
  - "Writing assertions about which fields have errors in a changeset"
  - "Any test module with multiple changeset tests"
  - "Shared test helpers or ExUnit.CaseTemplate for changeset testing"
---

# Use errors_on/1 helper for changeset error assertions

Ecto stores changeset errors as a keyword list of `{field, {message, opts}}` tuples.
Directly pattern-matching on this structure ties your tests to Ecto's internal format and
produces verbose, hard-to-read assertions. A small `errors_on/1` helper normalises the
errors into a `%{field => [message, ...]}` map, making assertions clean and stable.

This pattern is recommended in the official Phoenix test helpers and in the Ecto cookbook.

## Problem

```elixir
# Verbose and fragile — relies on Ecto's internal keyword list structure
assert {:email, {"can't be blank", [validation: :required]}} in changeset.errors
```

If Ecto ever changes the opts tuple structure, every test breaks. It's also hard to
read at a glance.

## Detection

- Tests that use `in changeset.errors` with tuple patterns
- Tests that call `List.keyfind(changeset.errors, field, 0)`
- Tests that call `Keyword.get(changeset.errors, field)` and match on the message tuple

## Bad

```elixir
test "requires email" do
  cs = User.changeset(%User{}, %{name: "Alice"})
  assert {:email, {"can't be blank", [validation: :required]}} in cs.errors
end
```

## Good

```elixir
defp errors_on(changeset) do
  Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end)
end

test "requires email" do
  cs = User.changeset(%User{}, %{name: "Alice"})
  assert "can't be blank" in errors_on(cs).email
end

test "requires name and email together" do
  errors = errors_on(User.changeset(%User{}, %{}))
  assert Map.has_key?(errors, :email)
  assert Map.has_key?(errors, :name)
end
```

## When This Applies

- Any test module that writes more than one or two changeset error assertions
- Shared test helpers via `ExUnit.CaseTemplate`

## Further Reading

- [Phoenix test helpers — errors_on/1](https://github.com/phoenixframework/phoenix/blob/main/installer/templates/phx_test/support/data_case.ex)
- [Ecto.Changeset.traverse_errors/2](https://hexdocs.pm/ecto/Ecto.Changeset.html#traverse_errors/2)
