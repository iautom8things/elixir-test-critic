---
id: ETC-ORG-003
title: "Don't test that libraries work"
category: organization
severity: recommendation
summary: >
  Trust that Ecto, Phoenix, Plug, Jason, and other well-tested libraries work correctly.
  Test the logic your application adds on top of them. Writing tests that only exercise
  library behaviour gives you noise without signal and slows your suite.
principles:
  - boundary-testing
applies_when:
  - "Tests whose assertions are entirely about library behaviour with no custom logic"
  - "Tests that verify `Jason.encode!/1` produces valid JSON, `Ecto.Changeset.cast/3` casts fields, etc."
  - "Schema tests that only verify field types defined via library macros"
does_not_apply_when:
  - "Your code wraps library behaviour with custom logic — test the custom logic"
  - "You have a bug report suggesting a library behaves unexpectedly in your context"
  - "You are building an adapter or wrapper around a library — test the adapter"
---

# Don't test that libraries work

Ecto, Phoenix, Jason, Plug, and other Hex packages are already tested by their
maintainers and by the Elixir community. Every time you write a test that only
verifies library behaviour, you are:

- Spending time writing a test that provides no confidence in your code
- Adding a test that will break if you upgrade the library (churn, not signal)
- Obscuring the tests that actually matter

## What to test instead

Test **the logic your application contributes**:

- Custom validation rules in changesets (not that `validate_required` works)
- Business rules derived from Ecto query results (not that Ecto can query)
- The structure of your Phoenix controller responses when your logic changes them
- Error handling logic built on top of library error tuples

## Detection

- Tests that only call library functions with constants and assert library return values
- Changeset tests that verify field casting without asserting custom validations
- Tests that duplicate what the library's own test suite already verifies
- Schema tests: `assert changeset.valid?` with no invalid cases

## Bad

```elixir
defmodule MyApp.UserTest do
  use ExUnit.Case, async: true

  test "user changeset casts email field" do
    # Testing that Ecto.Changeset.cast/3 works — not your code
    changeset = MyApp.User.changeset(%MyApp.User{}, %{email: "alice@example.com"})
    assert changeset.changes.email == "alice@example.com"
  end

  test "Jason encodes a map to JSON string" do
    # Testing that Jason works — not your code
    assert Jason.encode!(%{key: "value"}) == ~s({"key":"value"})
  end
end
```

## Good

```elixir
defmodule MyApp.UserTest do
  use ExUnit.Case, async: true

  test "user changeset requires email" do
    # Testing YOUR validation rule — that email is required
    changeset = MyApp.User.changeset(%MyApp.User{}, %{})
    assert "can't be blank" in errors_on(changeset).email
  end

  test "user changeset rejects email without @ sign" do
    # Testing YOUR custom email format validation
    changeset = MyApp.User.changeset(%MyApp.User{}, %{email: "notanemail"})
    assert "has invalid format" in errors_on(changeset).email
  end

  test "format_for_api/1 includes only public fields" do
    # Testing YOUR transformation logic built on top of Jason
    user = %MyApp.User{id: 1, email: "alice@example.com", password_hash: "secret"}
    json = MyApp.User.format_for_api(user)
    refute Map.has_key?(json, :password_hash)
    assert Map.has_key?(json, :email)
  end
end
```

## The signal to noise question

Before writing a test, ask: "If this test fails, does it mean my code is broken,
or does it mean the library is broken?" If the answer is "the library", delete the test.

## Further Reading

- [Testing Elixir — Contextual testing](https://pragprog.com/titles/lmelixir/testing-elixir/)
- [Don't test your framework](https://thoughtbot.com/blog/don-t-stub-the-system-under-test)
