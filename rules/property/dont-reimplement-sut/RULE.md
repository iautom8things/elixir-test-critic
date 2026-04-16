---
id: ETC-PROP-004
title: "Don't reimplement the system under test in properties"
category: property
severity: warning
summary: >
  A property test assertion that reimplements the same logic as the function
  under test provides zero confidence. If both contain the same bug, the test
  passes. Test invariants — properties of the output — rather than recomputing
  what the output should be.
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
0.20), both sides of the equality share the bug and the test tells you nothing.

## What to test instead

Test **invariants** — properties of the output that hold regardless of the exact
formula:

- The result is in a valid range
- The result has the correct type or structure
- The result changes monotonically as input grows
- The result satisfies a known relationship to the input
- Two functions are inverses of each other (roundtrip)

## Detection

- Property check body contains `== function_name(args)` re-derived from arguments using the same formula
- The property body reimplements the SUT logic step by step
- Removing the property test from the suite would not catch any regression that example tests don't already catch

## Bad

```elixir
property "BAD: discount calculation is correct for all amounts" do
  check all amount <- StreamData.integer(1..10_000) do
    # Reimplements the same formula — if 0.15 is wrong, both sides are wrong
    assert MyApp.Pricing.discount(:vip, amount) == trunc(amount * 0.15)
  end
end
```

## Good

```elixir
# Test invariants, not the exact formula
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

- [Fred Hebert — "Don't test what you know"](https://ferd.ca/property-based-testing.html)
- [Testing without a reference implementation](https://hypothesis.works/articles/testing-without-reference-implementation/)
