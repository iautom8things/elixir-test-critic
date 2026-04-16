---
id: ETC-ORG-004
title: "Minimize setup block scope"
category: organization
severity: recommendation
summary: >
  Use a setup block only when the same preparation code is shared across three or
  more tests and spans five or more lines. For fewer tests or shorter setup,
  inline the preparation inside each test. Broad setup blocks hide what each
  test actually needs and make tests harder to read in isolation.
principles:
  - purity-separation
applies_when:
  - "A setup block prepares data used by fewer than 3 tests"
  - "A setup block is shorter than 5 lines and only used by 1-2 tests"
  - "Tests in a describe block don't all use the same context keys from setup"
does_not_apply_when:
  - "The same 5+ line setup is genuinely shared across 3+ tests"
  - "Setup starts supervised processes that every test in the module requires"
  - "Database sandboxing or other test-framework lifecycle setup"
---

# Minimize setup block scope

A `setup` block runs before every test in its scope. When you put setup at the top
of a module, it runs before every test — including tests that don't need what setup
provides. This creates invisible coupling: a reader must cross-reference setup and
the test body to understand what state the test is operating on.

## The rule of thumb

Use `setup` when preparation is:
- Shared across **3 or more** tests, AND
- At least **5 lines** of code

Otherwise, inline the preparation inside each test.

## Problem

A broad `setup` block at module level that provides context for only some tests:

1. Forces every test reader to check whether the test uses `context` or has its own setup
2. Makes it impossible to understand a test by reading it alone
3. Runs expensive or irrelevant setup for tests that don't need it
4. Hides preconditions — the test body doesn't show what state it depends on

## Detection

- `setup` block with fewer than 5 lines shared across fewer than 3 tests
- Tests that don't use any key from the context map provided by setup
- `describe` blocks with a `setup` that only affects one test inside it
- Tests that partially override setup by re-binding the same variable

## Bad

```elixir
defmodule MyApp.AccountsTest do
  use ExUnit.Case, async: true

  # Setup runs for all 4 tests, but only 1 test uses `user`
  setup do
    user = %{id: 1, email: "alice@example.com"}
    {:ok, user: user}
  end

  test "registration returns ok", _context do
    # Doesn't use `user` from setup at all
    assert {:ok, _} = MyApp.Accounts.register(%{email: "bob@example.com"})
  end

  test "display name uses email when name is nil", %{user: user} do
    assert MyApp.Accounts.display_name(user) == "alice@example.com"
  end

  test "login fails for wrong password", _context do
    # Uses a completely different user — setup provides nothing useful
    assert {:error, :invalid_credentials} =
             MyApp.Accounts.login("charlie@example.com", "wrong")
  end

  test "logout clears session", _context do
    # Doesn't use setup either
    assert :ok = MyApp.Accounts.logout("some_token")
  end
end
```

## Good

```elixir
defmodule MyApp.AccountsTest do
  use ExUnit.Case, async: true

  test "registration returns ok" do
    assert {:ok, _} = MyApp.Accounts.register(%{email: "bob@example.com"})
  end

  test "display name uses email when name is nil" do
    user = %{id: 1, email: "alice@example.com"}  # inline — clear, local
    assert MyApp.Accounts.display_name(user) == "alice@example.com"
  end

  test "login fails for wrong password" do
    assert {:error, :invalid_credentials} =
             MyApp.Accounts.login("charlie@example.com", "wrong")
  end

  test "logout clears session" do
    assert :ok = MyApp.Accounts.logout("some_token")
  end

  # When setup IS appropriate: 3+ tests sharing 5+ lines of identical setup
  describe "with an existing verified user" do
    setup do
      {:ok, user} = MyApp.Accounts.register(%{email: "alice@example.com"})
      {:ok, _} = MyApp.Accounts.verify_email(user.id, user.verification_token)
      user = MyApp.Accounts.get_user!(user.id)
      {:ok, user: user}
    end

    test "can log in", %{user: user} do
      assert {:ok, _session} = MyApp.Accounts.login(user.email, "password")
    end

    test "appears in active users list", %{user: user} do
      users = MyApp.Accounts.list_active_users()
      assert user.id in Enum.map(users, & &1.id)
    end

    test "can request password reset", %{user: user} do
      assert {:ok, _token} = MyApp.Accounts.request_password_reset(user.email)
    end
  end
end
```

## Further Reading

- [ExUnit.Callbacks — setup/1](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html)
- [Testing Elixir — chapter on setup patterns](https://pragprog.com/titles/lmelixir/testing-elixir/)
