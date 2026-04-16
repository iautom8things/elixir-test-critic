---
id: ETC-MOCK-004
title: "Always verify mock expectations"
category: mocking
severity: critical
summary: >
  Call Mox.verify_on_exit! in every test that uses Mox.expect. Without it,
  unmet expectations are silently ignored and tests can pass even when the
  expected call was never made.
principles:
  - contracts-first
applies_when:
  - "Any test that uses Mox.expect/4 to set call-count expectations"
  - "Any test suite that uses Mox for dependency mocking"
does_not_apply_when:
  - "Using Mox.stub/3 where you explicitly don't want call count verification"
---

# Always verify mock expectations

`Mox.expect/4` sets an expectation that a function will be called a specific
number of times. But without `Mox.verify_on_exit!/1`, Mox never checks
whether those expectations were met. Unmet expectations silently pass.

## Problem

This is one of the most dangerous Mox mistakes. You write:

```elixir
expect(PaymentMock, :charge, 1, fn _amount -> {:ok, "txn"} end)
```

You are asserting that `charge/1` will be called exactly once. But if the
code under test is refactored to skip the payment call, Mox will never tell
you — unless `verify_on_exit!` is in place. The test turns green while the
real payment path is broken.

`Mox.verify_on_exit!/1` registers an ExUnit callback that calls
`Mox.verify!/0` after each test, checking that every `expect` was satisfied.

## Detection

- Test modules using `Mox.expect` without `setup :verify_on_exit!`
- Test modules that `import Mox` but never call `verify_on_exit!` or
  `Mox.verify!/1` explicitly
- `setup` blocks with `expect` calls but no verification registration

## Bad

```elixir
defmodule MyApp.OrderTest do
  use ExUnit.Case, async: true
  import Mox

  # Missing: setup :verify_on_exit!

  test "charges the gateway" do
    expect(PaymentMock, :charge, 1, fn _ -> {:ok, "txn"} end)
    # If create_order never calls charge, this test still passes!
    MyApp.Orders.create_order(%{items: []})
  end
end
```

## Good

```elixir
defmodule MyApp.OrderTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!  # Mox checks all expects after each test

  test "charges the gateway exactly once" do
    expect(PaymentMock, :charge, 1, fn _ -> {:ok, "txn"} end)
    MyApp.Orders.create_order(%{items: [], payment: %{token: "tok"}})
    # verify_on_exit! will fail this test if charge was never called
  end
end
```

## When This Applies

- All test modules that use `Mox.expect/4`
- The `setup :verify_on_exit!` line should be present in every module that
  imports Mox and sets any expectations

## When This Does Not Apply

- When you use only `Mox.stub/3` and explicitly do not want call-count
  verification. In this case, omitting `verify_on_exit!` is intentional,
  but document it clearly.

## Further Reading

- [Mox docs — verify_on_exit!/1](https://hexdocs.pm/mox/Mox.html#verify_on_exit!/1)
- [Mox docs — verify!/1](https://hexdocs.pm/mox/Mox.html#verify!/1)
- [José Valim — "Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
