---
id: ETC-MOCK-001
title: "Define a behaviour before creating a mock"
category: mocking
severity: critical
summary: >
  Every Mox mock must be backed by a behaviour module. Without a behaviour,
  there is no contract, and the mock is unverified guesswork that can drift
  silently from the real implementation.
principles:
  - contracts-first
  - mock-as-noun
applies_when:
  - "Creating a Mox mock for a module your code depends on"
  - "Defining an adapter or integration point with an external service"
  - "Any module boundary where you plan to swap implementations"
does_not_apply_when:
  - "Using Bypass or Req.Test for HTTP-level testing where the contract is HTTP itself"
---

# Define a behaviour before creating a mock

A Mox mock without a backing behaviour is a lie — it has no verified
relationship to the real implementation. The behaviour IS the contract; the
mock implements it; the real adapter implements it; your code depends on the
behaviour, not any specific module.

## Problem

When developers jump straight to creating a mock without defining a behaviour,
they create mocks that have no enforced relationship to the real implementation.
The mock can return `{:ok, %User{}}` while the real implementation returns
`{:ok, user}` with extra fields, or `{:error, :not_found}` instead of `nil`.
The mock diverges silently, and bugs surface only in production.

Mox enforces the contract at mock-definition time: `Mox.defmock/2` requires
a `:for` behaviour. If you can't provide one, you haven't defined a contract yet.

## Detection

- `Mox.defmock(MyMock, for: nil)` or any attempt to bypass the `:for` option
- Modules that are mocked without a corresponding `@behaviour` declaration
  in the real implementation
- Mock modules defined with `@callback`-less interfaces
- The real module does not `@behaviour MyApp.SomeBehaviour`

## Bad

```elixir
# No behaviour defined — mocking without a contract
defmodule MyApp.Mailer do
  def send_email(to, subject, body) do
    # calls real SMTP
  end
end

# In test_helper.exs — no behaviour to enforce the contract
Mox.defmock(MyApp.MailerMock, for: MyApp.Mailer)  # ERROR: not a behaviour
```

## Good

```elixir
# First: define the contract as a behaviour
defmodule MyApp.MailerBehaviour do
  @callback send_email(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
end

# Real implementation adopts the behaviour
defmodule MyApp.SMTPMailer do
  @behaviour MyApp.MailerBehaviour

  @impl true
  def send_email(to, subject, body), do: # real SMTP call
end

# Mock is verified against the behaviour
# In test_helper.exs:
Mox.defmock(MyApp.MailerMock, for: MyApp.MailerBehaviour)
```

## When This Applies

- Any time you want to use Mox to mock a dependency
- Defining adapters for external services (email, SMS, payment processors)
- Database adapters, HTTP clients, and other infrastructure boundaries

## When This Does Not Apply

- HTTP-level tests using Bypass or Req.Test, where the contract is the HTTP
  protocol itself rather than an Elixir callback interface
- Testing third-party library modules you cannot add a `@behaviour` to
  (in this case, wrap them in your own adapter that does implement a behaviour)

## Further Reading

- [José Valim — "Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
- [Mox docs — defmock/2](https://hexdocs.pm/mox/Mox.html#defmock/2)
- [Elixir docs — behaviours](https://hexdocs.pm/elixir/typespecs.html#behaviours)
