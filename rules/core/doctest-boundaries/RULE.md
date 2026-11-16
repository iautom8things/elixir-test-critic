---
id: ETC-CORE-010
title: "Limit doctests to pure functions"
category: core
severity: recommendation
summary: >
  Write doctests only for pure, deterministic functions. Doctests for functions
  with side effects (database writes, HTTP calls, process interactions) are fragile
  and hard to maintain: the example cannot show the setup it depends on, and its
  printed result drifts with the state it reads.
principles:
  - purity-separation
  - public-interface
applies_when:
  - "Any module with @doc examples for functions that have side effects"
  - "Functions that call external services, write to databases, or spawn processes"
---

# Limit doctests to pure functions

Doctests (`iex>` examples in `@doc`) are compiled and run by ExUnit when you call
`doctest MyModule`. They are excellent for documenting pure transformations —
showing exactly what a function returns given an input. They are a poor fit for
functions with side effects.

## Problem

A doctest is an ordinary test of the module that calls `doctest`. It runs with
that module's `setup` and case template. So a doctest can get an Ecto sandbox or
Mox setup, but only from the test module, never from the docstring. When a
doctest calls a function that writes to a database or spawns a process, one of
these follows:

1. **It fails**, because the test module that calls `doctest` is a plain
   `ExUnit.Case` with no sandbox checkout or running service
2. **It passes and leaves data behind**, because nothing wraps the write in a
   sandbox transaction
3. **It passes only through hidden setup**: the test module seeds data or checks
   out a sandbox that the reader of the documentation never sees, so the example
   does not work when pasted into `iex`

Doctests that show side-effectful behavior are also misleading:
the example output may depend on existing database state, server responses, or
environment variables, making the documentation inaccurate.

## Detection

- `doctest MyModule` in test files where `MyModule` has functions that call `Repo.*`,
  make HTTP requests, or send messages to processes
- `@doc` examples with `iex>` that show `{:ok, %Schema{}}` return values
- Doctests that require `Application.put_env` or setup before they can run

## Bad

```elixir
@doc """
Creates a user in the database.

    iex> MyApp.Accounts.create_user(%{name: "Alice", email: "alice@example.com"})
    {:ok, %MyApp.Accounts.User{name: "Alice"}}
"""
def create_user(attrs), do: Repo.insert(User.changeset(%User{}, attrs))
```

## Good

```elixir
@doc """
Validates the email format.

    iex> MyApp.Accounts.valid_email?("alice@example.com")
    true

    iex> MyApp.Accounts.valid_email?("not-an-email")
    false
"""
def valid_email?(email), do: Regex.match?(~r/^[^@]+@[^@]+$/, email)
```

For the side-effectful `create_user`, write a regular ExUnit test instead.

## When This Applies

- Functions that call `Repo.*`, `HTTPoison`, `Tesla`, `Finch`, `GenServer.call/cast`
- Functions that modify application state, spawn processes, or interact with external systems
- Functions whose return value depends on environment, time, or random values

## When This Does Not Apply

- Pure transformation functions: string formatting, data mapping, validation logic,
  mathematical calculations — these are ideal for doctests
- Functions that return deterministic results from pure inputs regardless of environment

## Further Reading

- [ExUnit.DocTest docs](https://hexdocs.pm/ex_unit/ExUnit.DocTest.html)
- [Elixir docs style guide](https://hexdocs.pm/elixir/writing-documentation.html)
