---
id: ETC-PROP-004
title: "Don't reimplement the system under test in properties"
category: property
severity: warning
summary: >
  A property whose assertion copies the formula of the function under test
  cannot catch a wrong formula: both sides share the bug. It only catches a
  later change, which one example test does as well. Use properties for
  invariants, and pin exact values with examples taken from the specification.
principles:
  - public-interface
applies_when:
  - "Writing a property test where the assertion uses the same algorithm as the function under test"
  - "The property check all body computes an expected value using the same formula as the SUT"
does_not_apply_when:
  - "The reference implementation is a different, independently-maintained version (oracle testing)"
  - "You are testing a known mathematical identity where reimplementation is unavoidable"
---

# Don't reimplement the system under test in properties

The most common property-testing mistake is writing a property whose assertion is
simply a copy of the implementation. When both the production code and the test
contain the same bug, the test passes and you have a false sense of coverage.

The purpose of a property is to express something *true about the output* without
computing what the output should be.

## Problem

Consider a function `discount/2` that computes a 15% discount:

```elixir
def discount(:vip, amount), do: trunc(amount * 0.15)
```

A property that asserts `discount(:vip, amount) == trunc(amount * 0.15)` is just
running the same multiplication twice. If the formula is wrong (e.g., should be
0.20), both sides of the equality share the bug and the property passes.

Such a property is not worthless. It fails if someone later changes the
implementation by accident. But a single example (`discount(:vip, 200) == 30`)
gives the same protection, and a hundred generated inputs add nothing to it.
The question to ask is whether the expected value comes from somewhere other
than the code: a specification, a worked example, a second implementation.

## What to test instead

Test **invariants** — properties of the output that hold regardless of the exact
formula:

- The result is in a valid range
- The result has the correct type or structure
- The result changes monotonically as input grows
- The result satisfies a known relationship to the input
- Two functions are inverses of each other (roundtrip)

Invariants alone are not enough either. Every invariant above still holds if
the rate is 0.20 instead of 0.15. Keep a few example tests that pin exact values
from the specification, and use properties for what must hold across all inputs.

## Detection

- Property check body contains `== function_name(args)` re-derived from arguments using the same formula
- The property body reimplements the SUT logic step by step
- Removing the property test from the suite would not catch any regression that example tests don't already catch

## Bad

```elixir
property "BAD: discount calculation is correct for all amounts" do
  check all amount <- StreamData.integer(1..10_000) do
    # Copies the formula. If 0.15 is the wrong rate, both sides are wrong.
    assert MyApp.Pricing.discount(:vip, amount) == trunc(amount * 0.15)
  end
end
```

## Good

```elixir
# Pin the exact values with examples from the specification
test "vip discount is 15% of the amount, rounded down" do
  assert MyApp.Pricing.discount(:vip, 200) == 30
  assert MyApp.Pricing.discount(:vip, 199) == 29
end

# Use properties for what must hold for every input
property "discount is always non-negative and never exceeds the purchase amount" do
  check all amount <- StreamData.integer(1..10_000),
            tier <- StreamData.member_of([:standard, :vip, :platinum]) do
    discount = MyApp.Pricing.discount(tier, amount)
    assert discount >= 0
    assert discount <= amount
  end
end

property "higher tiers always get a larger or equal discount" do
  check all amount <- StreamData.integer(1..10_000) do
    assert MyApp.Pricing.discount(:platinum, amount) >=
             MyApp.Pricing.discount(:vip, amount)

    assert MyApp.Pricing.discount(:vip, amount) >=
             MyApp.Pricing.discount(:standard, amount)
  end
end

property "discount grows with purchase amount for same tier" do
  check all small <- StreamData.integer(1..100),
            large <- StreamData.integer(101..1000) do
    assert MyApp.Pricing.discount(:vip, large) >=
             MyApp.Pricing.discount(:vip, small)
  end
end
```

## Further Reading

- [Fred Hebert: Property-Based Testing](https://ferd.ca/property-based-testing.html)
