---
id: ETC-MOCK-009
title: "Don't mock your own pure functions"
category: mocking
severity: warning
summary: >
  Pure functions — those with no side effects that return the same output for
  the same input — should never be mocked. Call them directly. Mocking pure
  functions defeats the purpose of having them and creates tests that prove
  nothing about the real logic.
principles:
  - purity-separation
  - mock-as-noun
applies_when:
  - "The function being mocked is deterministic and has no side effects"
  - "The function transforms data without accessing I/O, processes, or external state"
  - "The module being mocked belongs to your own application (not an external adapter)"
related_rules:
  - ETC-ABS-001
---

# Don't mock your own pure functions

A pure function takes inputs and returns outputs. It has no side effects and is
completely deterministic. There is nothing to mock — just call it and assert on
the result.

## Problem

When developers mock their own pure functions, they create tests that test
nothing real. The mock returns a hardcoded value, the code under test sees that
value, and the test passes. If the real pure function is deleted, renamed, or
broken, these tests continue to pass.

Mocking pure functions is also a design signal: if you feel you need to mock a
pure function to isolate it, you may be testing at the wrong level. The pure
function should be testable on its own. Test it directly.

Common offenders: mocking price calculation modules, string formatters,
data validators, schema transformers, and sorting/filtering functions.

## Detection

- Mox mocks defined for modules containing only data-transformation functions
- Behaviours defined for modules with no I/O operations
- Mock expectations on functions like `calculate_total`, `format_name`,
  `validate_email`, `parse_response` that are clearly pure
- The behaviour being mocked has no callbacks involving external state

## Bad

```elixir
# Mocking a pure tax calculator to test the order module
defmodule MyApp.OrderTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  test "order total includes tax" do
    # TaxCalculator is pure — no I/O, completely deterministic
    expect(MyApp.TaxCalculatorMock, :calculate, 1, fn 100 -> 8 end)
    order = MyApp.Orders.create(%{subtotal: 100, tax_module: MyApp.TaxCalculatorMock})
    assert order.total == 108
    # The real TaxCalculator logic is never tested
  end
end
```

## Good

```elixir
# Test the pure tax calculator directly
defmodule MyApp.TaxCalculatorTest do
  use ExUnit.Case, async: true

  test "calculates 8% tax on amount" do
    assert MyApp.TaxCalculator.calculate(100) == 8
    assert MyApp.TaxCalculator.calculate(50) == 4
  end
end

# Test the order module with the real tax calculator
defmodule MyApp.OrderTest do
  use ExUnit.Case, async: true

  test "order total includes tax from real calculator" do
    # No mock needed — TaxCalculator is pure and fast
    order = MyApp.Orders.create(%{subtotal: 100})
    assert order.total == 108
  end
end
```

## When This Applies

- Data transformation modules (formatters, parsers, validators)
- Mathematical computation modules (calculators, converters)
- Pure filtering and sorting functions
- Any module that does not call external services, processes, or I/O

## When This Does Not Apply

- A function that appears pure but actually reads from the database or calls
  an external service under the hood — this is an impure function in disguise
  and a candidate for mocking at that boundary
- When you are testing that a higher-level module correctly passes arguments
  to a collaborator — in this case, mock the collaborator to capture and assert
  on the arguments

## Further Reading

- [José Valim — "Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
- [Elixir — Pure functions and immutability](https://elixir-lang.org/getting-started/basic-types.html)
- [Testing Elixir (Pragmatic) — Unit testing pure functions](https://pragprog.com/titles/lmelixir/testing-elixir/)
