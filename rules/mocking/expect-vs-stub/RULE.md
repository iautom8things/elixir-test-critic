---
id: ETC-MOCK-003
title: "Use expect when verifying calls, stub for setup"
category: mocking
severity: recommendation
summary: >
  Use Mox.expect/4 when you want to assert that a function is called a specific
  number of times. Use Mox.stub/3 when you need a mock to return a value for
  setup purposes without caring how many times it is called.
principles:
  - contracts-first
applies_when:
  - "A test needs to assert that an external call was made (or not made)"
  - "A test needs a mock to return a value for setup without caring about call count"
  - "Multiple tests share a common mock response but differ in what they verify"
---

# Use expect when verifying calls, stub for setup

`Mox.expect/4` and `Mox.stub/3` look similar but serve different purposes.
`expect` asserts a specific call count and fails if the expectation is not met.
`stub` provides a fallback response without any call-count verification.

## Problem

Using `expect` everywhere forces you to assert on call counts even when the
count is not what you're testing. A setup block that stubs a token-fetch might
use `expect(:fetch_token, 1, ...)` when really you just need the mock to return
a token whenever asked during the test. If your production code path changes to
call `fetch_token` twice, the test fails for the wrong reason.

Conversely, using `stub` everywhere means you lose the safety net of verifying
that important calls (like `send_payment`) actually happened.

Rule of thumb: **expect for outcomes, stub for setup**.

## Detection

- `expect` calls in `setup` blocks where call count is irrelevant
- `stub` calls when the test is specifically verifying that an external
  call was made exactly once (or N times)
- Expectations with count 1 in tests that would pass even if the call
  never happened (because `verify_on_exit!` is missing — see ETC-MOCK-004)

## Bad

```elixir
setup do
  # expect in setup forces call count — breaks if code path calls it 0 or 2 times
  expect(MyApp.TokenMock, :fetch, 1, fn -> {:ok, "test-token"} end)
  :ok
end

test "creates resource" do
  # stub here — doesn't verify that the critical payment call was made
  stub(MyApp.PaymentMock, :charge, fn _amount -> {:ok, "txn_123"} end)
  MyApp.Orders.create_and_charge(%{amount: 100})
  # No assertion that charge was actually called!
end
```

## Good

```elixir
setup do
  # stub in setup — don't care how many times token is fetched during the test
  stub(MyApp.TokenMock, :fetch, fn -> {:ok, "test-token"} end)
  :ok
end

test "charges payment gateway exactly once" do
  # expect for the outcome we care about — verifies the call was made
  expect(MyApp.PaymentMock, :charge, 1, fn 100 -> {:ok, "txn_123"} end)
  MyApp.Orders.create_and_charge(%{amount: 100})
  # verify_on_exit! will confirm :charge was called exactly once
end
```

## When This Applies

- `setup` blocks that establish shared mock state for a test suite
- Tests verifying that a side-effecting call (payment, email, webhook) occurred
- Tests that want to verify a call was NOT made (use `expect` with count 0)

## When This Does Not Apply

- When you genuinely need to assert on call order or argument patterns across
  multiple calls — use multiple `expect` calls with different argument matchers

## Further Reading

- [Mox docs — expect/4](https://hexdocs.pm/mox/Mox.html#expect/4)
- [Mox docs — stub/3](https://hexdocs.pm/mox/Mox.html#stub/3)
- [Mox docs — stub_with/2](https://hexdocs.pm/mox/Mox.html#stub_with/2)
