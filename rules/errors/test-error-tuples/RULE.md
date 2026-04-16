---
id: ETC-ERR-002
title: "Test both success and error return paths"
category: errors
severity: warning
summary: >
  Functions returning `{:ok, result} | {:error, reason}` require tests for both
  paths. Match on the specific reason atom or struct in error cases — not just
  `{:error, _}` — to ensure the right error is returned for the right input.
principles:
  - boundary-testing
applies_when:
  - "Functions with {:ok, result} | {:error, reason} return signatures"
  - "Ecto changesets, HTTP clients, parsers, and any function that can legitimately fail"
---

# Test both success and error return paths

A function with a `{:ok, _} | {:error, _}` signature has two observable behaviors.
Testing only the happy path leaves the error path entirely uncovered — bugs in error
handling (wrong reason atom, missing fields in error structs, no error path at all)
go undetected until they surface in production.

## Problem

Error path bugs are common and insidious:

1. **Wrong reason**: the function returns `{:error, :not_found}` when it should return
   `{:error, :unauthorized}` — but since the test only checks `{:ok, _}`, the
   distinction is never verified
2. **Missing error path**: the function crashes instead of returning `{:error, reason}`
   — only discovered when the caller receives an unexpected crash in production
3. **Overly broad matching**: `assert {:error, _} = result` verifies an error was
   returned but doesn't verify which error, allowing the wrong error to pass the test

The fix is to write dedicated tests for each error path and match specifically on the
reason value.

## Detection

- Test modules with `describe` blocks for a function that have no tests containing `{:error, ...}`
- `assert {:error, _} = result` without matching the specific reason
- Functions with multiple possible error reasons but only one error test

## Bad

```elixir
describe "find_user/1" do
  test "returns the user" do
    user = insert!(:user, email: "alice@example.com")
    assert {:ok, found} = find_user(user.id)
    assert found.email == "alice@example.com"
  end
  # No test for the error path — what happens when the user doesn't exist?
end
```

## Good

```elixir
describe "find_user/1" do
  test "returns {:ok, user} when user exists" do
    user = insert!(:user, email: "alice_#{unique()}@example.com")
    assert {:ok, found} = find_user(user.id)
    assert found.email == user.email
  end

  test "returns {:error, :not_found} when no user exists with that id" do
    assert {:error, :not_found} = find_user(999_999)
  end
end
```

And for multiple error reasons:

```elixir
describe "transfer_funds/3" do
  test "returns {:ok, transaction} on success" do ... end
  test "returns {:error, :insufficient_funds} when balance is too low" do ... end
  test "returns {:error, :account_frozen} when source account is frozen" do ... end
end
```

## When This Applies

- Any function with `{:ok, _} | {:error, _}` return type
- Ecto `Repo.insert/1`, `Repo.update/1`, changeset validations
- HTTP client wrappers, file I/O operations, parser functions
- Any function that can legitimately fail without crashing

## When This Does Not Apply

- Functions that raise exceptions instead of returning error tuples — use
  `assert_raise` for those (see ETC-ERR-001)
- Functions that always succeed by design (pure transformations with total coverage)

## Further Reading

- [Elixir — tagged tuple convention](https://hexdocs.pm/elixir/Kernel.html#match?/2)
- [Ecto.Changeset error handling](https://hexdocs.pm/ecto/Ecto.Changeset.html)
