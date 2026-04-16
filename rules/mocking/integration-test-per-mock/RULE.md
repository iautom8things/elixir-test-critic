---
id: ETC-MOCK-008
title: "Write at least one integration test per mocked boundary"
category: mocking
severity: warning
summary: >
  For every external boundary you mock, write at least one integration test
  that exercises the real implementation. Mocks prove your code handles the
  contract correctly; integration tests prove the real implementation works.
principles:
  - integration-required
applies_when:
  - "You have a Mox mock for an external service adapter"
  - "The adapter has a real implementation that can be tested against a sandbox or local service"
  - "The boundary is a database, external API, email service, or message queue"
related_rules:
  - ETC-ABS-002
---

# Write at least one integration test per mocked boundary

Mocks prove that your code correctly uses the contract. Integration tests prove
that the real implementation fulfills the contract. You need both. A codebase
full of mock tests but no integration tests has gaps where the real adapter
may break silently.

## Problem

A comprehensive mock test suite can give false confidence. The mocks return
the values your code expects — but are those the values the real service
actually returns? Is the JSON structure correct? Does authentication work?
Does the real service use different error codes?

At least one integration test per boundary catches these divergences. It
doesn't have to be run in every CI job — it can be tagged `@tag :integration`
and run nightly or before release. What matters is that it exists.

## Detection

- A codebase where every external adapter has Mox tests but no corresponding
  integration test file or tag
- `Mox.defmock` calls without any paired `@tag :integration` test using the
  real implementation
- Adapter modules with no test coverage of their `@impl` functions

## Bad

```elixir
# Only mock tests exist — real adapter is never exercised
defmodule MyApp.StripeAdapterTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "charge calls the mock" do
    expect(MyApp.PaymentMock, :charge, 1, fn _ -> {:ok, "txn_123"} end)
    assert {:ok, "txn_123"} = MyApp.Billing.charge(MyApp.PaymentMock, 100)
  end
  # The real StripeAdapter is never tested — it could be completely broken
end
```

## Good

```elixir
# Mock tests for speed and isolation
defmodule MyApp.BillingTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "charge delegates to payment adapter" do
    expect(MyApp.PaymentMock, :charge, 1, fn _ -> {:ok, "txn_mock"} end)
    assert {:ok, "txn_mock"} = MyApp.Billing.charge(MyApp.PaymentMock, 100)
  end
end

# Integration test for the real adapter
defmodule MyApp.StripeAdapterIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  test "charge creates a real transaction in Stripe test mode" do
    assert {:ok, txn_id} = MyApp.StripeAdapter.charge(100)
    assert is_binary(txn_id)
    assert String.starts_with?(txn_id, "txn_")
  end
end
```

## When This Applies

- Every module that has a Mox mock and a real implementation
- Database adapters, HTTP clients, email services, payment gateways
- File storage adapters (S3, GCS)

## When This Does Not Apply

- Adapters where no sandbox or test environment exists (rare for major services)
- Third-party libraries you don't own — their own test suite covers their implementation
- When the integration test environment is unavailable (e.g., no Stripe test API key
  in CI) — in this case, document the gap and ensure it's tested in another environment

## Further Reading

- [Testing Elixir (Pragmatic) — Integration tests](https://pragprog.com/titles/lmelixir/testing-elixir/)
- [ExUnit — tags](https://hexdocs.pm/ex_unit/ExUnit.Case.html#module-tags)
- [Mox rationale — testing pyramid](https://hexdocs.pm/mox/readme.html)
