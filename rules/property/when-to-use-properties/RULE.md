---
id: ETC-PROP-001
title: "Use property tests for invariants, examples for specifics"
category: property
severity: recommendation
summary: >
  Reach for property-based testing when you can articulate an invariant that holds
  for all valid inputs. Use example-based tests for specific business rules, edge
  cases, and exact output expectations. The two styles are complementary, not competing.
principles:
  - boundary-testing
applies_when:
  - "You can express a general rule about the output that holds for any valid input"
  - "Testing functions with a large or unbounded input space (strings, numbers, lists)"
  - "Roundtrip / invertibility properties (encode/decode, parse/serialize)"
  - "Mathematical properties: commutativity, associativity, idempotence"
  - "Ordering and structural invariants: sort stability, non-empty output, key preservation"
does_not_apply_when:
  - "You need to assert exact output for a specific input — use an example test"
  - "The invariant requires domain knowledge that's hard to express as a generator constraint"
  - "The function's behaviour depends on external state that can't be controlled in a generator"
---

# Use property tests for invariants, examples for specifics

Property-based testing with StreamData shines when you can express a property of
the form: "for all X that satisfy condition C, f(X) satisfies property P". If you
cannot express a meaningful property, an example test is the right tool.

## When to use property tests

**Good property targets:**

- **Roundtrips** — `decode(encode(x)) == x` for any encodable `x`
- **Ordering** — `Enum.sort(list)` is always non-descending for any list
- **Length invariants** — `String.split(s, sep) |> Enum.join(sep) == s` for any `s` and `sep`
- **Structural preservation** — map keys are never lost in a transformation
- **Range invariants** — normalised scores are always between 0.0 and 1.0

**Use example tests instead when you need:**

- Exact output: `format_currency(1234, :usd) == "$12.34"`
- Business rule specifics: `discount_for(:vip, 100) == 15`
- Error messages: `{:error, "Name can't be blank"}`
- Boundary conditions: `min_age_for(:alcohol) == 21`

## Detection

- A property test whose `check all` body just compares `f(x) == hardcoded_value`
  — this is an example test in disguise
- An example test that has 10+ parameterised cases all testing the same general
  property — this should be a property test

## Bad

```elixir
# Using property testing for a specific business rule — wrong tool
property "discount for vip is 15%" do
  check all amount <- integer(1..1000) do
    # The property is actually a specific rule, not a general invariant
    # Example test is clearer here
    assert MyApp.Pricing.discount(:vip, amount) == trunc(amount * 0.15)
  end
end
```

## Good

```elixir
# Use example tests for specific business rules
test "VIP discount is 15% of the purchase amount" do
  assert MyApp.Pricing.discount(:vip, 100) == 15
  assert MyApp.Pricing.discount(:vip, 200) == 30
end

# Use property tests for the invariant that discount is never negative
# and never exceeds the purchase amount
property "discount is always between 0 and the purchase amount" do
  check all amount <- integer(1..10_000),
            tier <- member_of([:standard, :vip, :platinum]) do
    discount = MyApp.Pricing.discount(tier, amount)
    assert discount >= 0
    assert discount <= amount
  end
end
```

## Further Reading

- [StreamData documentation](https://hexdocs.pm/stream_data/StreamData.html)
- [José Valim — "Property-based testing is a mindset"](https://dashbit.co/blog/property-based-testing-is-a-mindset)
- [Fred Hebert — "Property-Based Testing with PropEr, Erlang, and Elixir"](https://pragprog.com/titles/fhproper/property-based-testing-with-proper-erlang-and-elixir/)
