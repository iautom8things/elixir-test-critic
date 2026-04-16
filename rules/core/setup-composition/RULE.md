---
id: ETC-CORE-003
title: "Compose setup with named functions, not nesting"
category: core
severity: recommendation
summary: >
  Build test setup by composing named helper functions rather than nesting multiple
  `setup` blocks or duplicating setup logic. Named functions make setup readable,
  reusable, and independently testable.
principles:
  - purity-separation
applies_when:
  - "When multiple tests or describe blocks share setup logic"
  - "When setup logic is complex enough that a flat `setup` block becomes hard to read"
  - "When setup involves multiple independent concerns (e.g., creating a user AND starting a server)"
---

# Compose setup with named functions, not nesting

Extract setup logic into named private functions and call them from `setup` rather
than nesting multiple `setup` blocks or duplicating setup code across describe blocks.
Named functions have explicit inputs and outputs, making them easy to read and reuse.

## Problem

Nested `setup` blocks accumulate context keys invisibly — later `setup` calls can
see all keys from earlier `setup` calls, creating implicit coupling. When setup
changes, you must trace the execution order to understand what context is available.
Duplicated setup code in multiple describe blocks drifts out of sync silently.

A common failure mode: a developer adds a `setup` block inside a `describe` block
without realising that the outer `setup` also runs, causing double-initialisation
or subtle state conflicts.

## Detection

- More than one `setup` block in a single test module (especially nested)
- Identical `setup` blocks duplicated across multiple `describe` blocks
- `setup` blocks that grow beyond 10 lines
- `context` maps with many keys that were built by several invisible `setup` calls

## Bad

```elixir
defmodule MyApp.OrderTest do
  use ExUnit.Case, async: true

  setup do
    user = %{id: 1, name: "Alice"}
    %{user: user}
  end

  describe "create/2" do
    setup do
      # Duplicated — also creates a user-like thing
      account = %{id: 99, owner_id: 1}
      %{account: account}
    end

    test "creates order", %{user: user, account: account} do
      assert user.id == account.owner_id
    end
  end
end
```

## Good

```elixir
defmodule MyApp.OrderTest do
  use ExUnit.Case, async: true

  setup :create_user

  describe "create/2" do
    setup :create_account

    test "creates order for user", %{user: user, account: account} do
      assert user.id == account.owner_id
    end
  end

  defp create_user(_context) do
    %{user: %{id: 1, name: "Alice"}}
  end

  defp create_account(%{user: user}) do
    %{account: %{id: 99, owner_id: user.id}}
  end
end
```

## When This Applies

- Any test module where setup logic is shared across multiple tests or describe blocks
- Setup that depends on other setup values (express the dependency explicitly as a function argument)
- Complex setup that would benefit from being named and documented independently

## When This Does Not Apply

- A single `setup` block with 2-3 lines is fine inline — extracting a named function
  adds more lines than it saves
- Test modules with a single describe block and trivial setup

## Further Reading

- [ExUnit.Callbacks — setup/1](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#setup/1)
- [Elixir Forum — Composing ExUnit setup](https://elixirforum.com/t/composing-exunit-setup/30952)
