---
id: ETC-MOCK-002
title: "Only mock at system boundaries"
category: mocking
severity: warning
summary: >
  Mocks should only replace modules at the edges of your system — HTTP clients,
  email services, payment processors, external APIs. Mocking internal modules
  creates brittle tests that break on every refactoring.
principles:
  - boundary-testing
  - mock-as-noun
applies_when:
  - "The dependency being mocked calls an external service (HTTP, SMTP, etc.)"
  - "The dependency being mocked accesses the filesystem or hardware"
  - "The dependency manages shared state that tests cannot own (global process, OS resource)"
related_rules:
  - ETC-ABS-003
---

# Only mock at system boundaries

A boundary is where your code meets the world outside your application: a
database, a third-party API, an email provider, a message queue. Mock those.
Do not mock your own internal modules — test them directly instead.

## Problem

When developers mock internal modules (their own application's pure functions
or data-transformation pipelines), they decouple the test from the actual code
being called. The test passes even if the real internal module is removed,
renamed, or broken, because the test never calls it. Every internal mock is a
lie about what the code does.

Internal mocking is also a design smell: if you feel you need to mock an
internal module to isolate it, the dependency probably should be injected
differently, or the logic should be extracted into a pure function that can
be called directly.

## Detection

- `Mox` expectations set on modules that are part of your own application,
  not external adapters
- Mock modules named `MyApp.SomePureFunctionMock` or `MyApp.CalculatorMock`
- The module being mocked contains only pure data transformations with no I/O

## Bad

```elixir
# Mocking an internal pure module — tests are now disconnected from the real logic
defmodule MyApp.OrderTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "creates order with correct total" do
    # Pricing is an internal pure module — mocking it defeats the test
    MyApp.PricingMock
    |> expect(:calculate_total, fn _items -> Decimal.new("99.99") end)

    order = MyApp.Orders.create(%{items: [%{sku: "ABC", qty: 1}]})
    assert order.total == Decimal.new("99.99")
  end
end
```

## Good

```elixir
# Mock only the external payment gateway boundary
defmodule MyApp.OrderTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "creates order with correct total and charges payment gateway" do
    # Real pricing logic runs — test verifies the actual calculation
    # Only the external payment boundary is mocked
    MyApp.PaymentGatewayMock
    |> expect(:charge, fn _amount, _card -> {:ok, %{transaction_id: "txn_123"}} end)

    order = MyApp.Orders.create(%{
      items: [%{sku: "ABC", qty: 1, price: Decimal.new("99.99")}],
      payment: %{card_token: "tok_abc"}
    })

    assert order.total == Decimal.new("99.99")
    assert order.transaction_id == "txn_123"
  end
end
```

## When This Applies

- Mocking HTTP clients (`Tesla`, `Finch`, `Req`, `HTTPoison`)
- Mocking email adapters (Swoosh, Bamboo)
- Mocking payment gateways, SMS providers, OAuth services
- Mocking filesystem or OS-level operations

## When This Does Not Apply

- When an internal module manages a resource you genuinely cannot own in tests
  (e.g., a global process that is not supervised per-test)
- When you are writing tests for a library and the "internal" module is
  actually a plugin boundary intended for user customisation

## Further Reading

- [José Valim — "Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
- [Growing Object-Oriented Software — "Don't Mock What You Don't Own"](http://www.growing-object-oriented-software.com/)
- [Mox — README and design rationale](https://hexdocs.pm/mox/readme.html)
