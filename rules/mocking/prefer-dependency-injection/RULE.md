---
id: ETC-MOCK-007
title: "Prefer dependency injection over application config"
category: mocking
severity: recommendation
summary: >
  Pass dependencies as function arguments or module attributes rather than
  reading them from Application.get_env at call time. Dependency injection
  makes the contract explicit, enables async tests, and avoids global state
  mutation in test setup.
principles:
  - purity-separation
  - contracts-first
applies_when:
  - "A module reads its implementation dependency from Application.get_env"
  - "Tests must set Application.put_env to control which implementation is used"
  - "The dependency is an adapter (HTTP client, mailer, storage) that varies per environment"
related_rules:
  - ETC-ISO-001
  - ETC-BWAY-001
---

# Prefer dependency injection over application config

Reading a dependency from `Application.get_env` at call time couples the
module to global mutable state. Every test that needs to control the dependency
must call `Application.put_env`, which is not safe for async tests and makes
test setup verbose.

## Problem

The `Application.get_env` pattern for swapping implementations is tempting
because it requires no change to the public API. But it has serious drawbacks:

1. **Not async-safe**: `Application.put_env` mutates global state. Two async
   tests that both set the same key will interfere with each other.
2. **Hidden contract**: The dependency is invisible in function signatures. You
   can't tell what implementations are valid by reading the function.
3. **Brittle test setup**: Tests must call `on_exit(fn -> Application.put_env ... end)`
   to restore state, creating teardown boilerplate.

Dependency injection solves all three: the dependency is passed explicitly,
tests pass mock modules as arguments, and no global state is mutated.

## Detection

- `Application.get_env(:my_app, :mailer)` inside function bodies (not in config)
- Tests with `Application.put_env` + `on_exit` for cleanup
- `mix.exs` configs like `config :my_app, :http_client, MyApp.HttpClient`
  used as a runtime dispatch mechanism (rather than compile-time config)

## Bad

```elixir
defmodule MyApp.Mailer do
  def send(to, subject, body) do
    adapter = Application.get_env(:my_app, :mailer_adapter)
    adapter.deliver(to, subject, body)
  end
end

# In test — not async-safe, must clean up global state
test "sends email" do
  Application.put_env(:my_app, :mailer_adapter, MyApp.MailerMock)
  on_exit(fn -> Application.put_env(:my_app, :mailer_adapter, MyApp.SMTPMailer) end)
  expect(MyApp.MailerMock, :deliver, 1, fn _, _, _ -> :ok end)
  MyApp.Mailer.send("a@b.com", "Hi", "body")
end
```

## Good

```elixir
defmodule MyApp.Mailer do
  def send(adapter \\ MyApp.SMTPMailer, to, subject, body) do
    adapter.deliver(to, subject, body)
  end
end

# In test — async-safe, no global state mutation
test "sends email" do
  expect(MyApp.MailerMock, :deliver, 1, fn _, _, _ -> :ok end)
  MyApp.Mailer.send(MyApp.MailerMock, "a@b.com", "Hi", "body")
end
```

## When This Applies

- Modules that adapt to external services (mailer, SMS, payment, storage)
- Any module where the implementation varies between test and production
- New code being written — apply this pattern from the start

## When This Does Not Apply

- Application-wide configuration that is set once at startup and never changes
  during a test run (database pool size, log level, etc.)
- Third-party libraries that use `Application.get_env` internally — you can't
  change their API, so `Application.put_env` in `setup_all` is acceptable there

## Further Reading

- [José Valim — "Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
- [Dependency injection in Elixir (Dashbit blog)](https://dashbit.co/)
- [Testing Elixir (Pragmatic) — Chapter on test isolation](https://pragprog.com/titles/lmelixir/testing-elixir/)
