---
id: ETC-ORG-002
title: "Test behavior, not interactions"
category: organization
severity: warning
summary: >
  Assert that calling function A produces the correct result or observable side effect,
  not that A called B internally. Tests that verify internal call sequences are brittle:
  they break whenever you refactor the internals, even when the behaviour is unchanged.
principles:
  - public-interface
  - boundary-testing
applies_when:
  - "Any test that uses Mox.expect/4 to verify internal function calls between owned modules"
  - "Tests that assert on call counts or argument ordering inside a pipeline"
  - "Tests that break when you extract a private function or rename an internal helper"
does_not_apply_when:
  - "Verifying calls to external boundaries you don't own (HTTP clients, email adapters, payment gateways)"
  - "Testing that an event was published or a side-channel notification was sent"
  - "Mock expectations at integration boundaries where call verification is the contract"
---

# Test behavior, not interactions

A test that verifies interactions asks: "Did A call B with argument X?"
A test that verifies behaviour asks: "Given input Y, did the system produce output Z?"

Interaction-based tests are coupled to implementation details. When you inline a
helper, extract a function, or change the internal sequence of calls, interaction
tests break — even though the externally visible behaviour is identical.
Behaviour-based tests survive refactoring.

## The rule of thumb

Mock (and verify calls on) things **outside your system boundary**: HTTP endpoints,
third-party APIs, email services, payment gateways. For internal modules that you
own and control, test the observable output instead of the call sequence.

## Problem

```elixir
# Test verifies that Orders calls Inventory internally — breaks on extraction/rename
test "place_order calls Inventory.reserve" do
  Mox.expect(MockInventory, :reserve, fn _item, _qty -> :ok end)
  MyApp.Orders.place_order(%{item: "widget", qty: 2})
  Mox.verify!()
end
```

If you later inline `Inventory.reserve/2` into `Orders`, or rename the module,
this test fails — even though orders are still placed correctly.

## Detection

- `Mox.expect` calls that verify internal module interactions
- Tests whose only assertion is `Mox.verify!/0` (no result or side-effect assertion)
- Tests that break when you rename or extract an internal function
- Test descriptions that say "calls X" rather than "returns Y" or "creates Z"

## Bad

```elixir
defmodule MyApp.OrdersTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "place_order calls Inventory.reserve with correct args" do
    # Testing internal interaction — breaks on any internal refactor
    expect(MockInventory, :reserve, fn "widget", 2 -> :ok end)

    MyApp.Orders.place_order(%{item: "widget", qty: 2})
    # No assertion on the return value or observable outcome — only interaction verified
  end
end
```

## Good

```elixir
defmodule MyApp.OrdersTest do
  use ExUnit.Case, async: true

  test "place_order reserves inventory and returns confirmed order" do
    result = MyApp.Orders.place_order(%{item: "widget", qty: 2})

    # Assert the observable outcome, not which internal function was called
    assert {:ok, order} = result
    assert order.status == :confirmed
    assert order.item == "widget"
  end

  test "place_order returns error when item is out of stock" do
    result = MyApp.Orders.place_order(%{item: "sold_out_item", qty: 1})
    assert {:error, :out_of_stock} = result
  end
end
```

## When verifying interactions is correct

At system boundaries — external HTTP calls, message queues, email delivery — you
cannot observe the outcome by querying your own database, so interaction verification
is appropriate:

```elixir
test "sends welcome email after registration" do
  # Email is an external boundary — call verification is the only way to confirm
  expect(MockMailer, :send, fn %{to: "alice@example.com", template: :welcome} -> :ok end)
  MyApp.Accounts.register(%{email: "alice@example.com"})
end
```

## Further Reading

- [Martin Fowler — "Mocks Aren't Stubs"](https://martinfowler.com/articles/mocksArentStubs.html)
- [José Valim — "Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
