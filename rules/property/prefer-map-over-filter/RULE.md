---
id: ETC-PROP-003
title: "Prefer map over filter in generators"
category: property
severity: warning
summary: >
  Avoid StreamData.filter/2 when the rejection rate is high. filter/2 raises
  FilterTooNarrowError after too many consecutive rejections. Use map/2 or
  bind/2 to construct valid data directly from a generator that already
  satisfies your constraints.
principles:
  - honest-data
applies_when:
  - "Generating data that must satisfy a constraint (e.g., even numbers, non-empty strings, valid emails)"
  - "Your filter predicate rejects more than ~10% of generated values"
  - "You see FilterTooNarrowError in a property test"
does_not_apply_when:
  - "The rejection rate is very low — filter/2 is fine for occasional exclusions"
  - "You need to model truly rare valid inputs and rejection is acceptable"
---

# Prefer map over filter in generators

`StreamData.filter/2` generates a value, tests it against a predicate, and discards it
if the predicate returns false. StreamData tries up to 25 times (by default) before
raising `StreamData.FilterTooNarrowError`. This happens when your predicate rejects
too large a fraction of the generated space.

The fix is to generate only valid data in the first place using `map/2` or `bind/2`,
so no values need to be discarded.

## Problem

Consider generating even integers. Using `filter/2` with `integer()` rejects ~50%
of values. StreamData may or may not hit the rejection limit depending on your
`max_runs` and seed, making your test intermittently raise `FilterTooNarrowError`.

```elixir
# Raises FilterTooNarrowError ~50% rejection rate:
check all n <- StreamData.filter(StreamData.integer(), &(rem(&1, 2) == 0)) do
  assert rem(n, 2) == 0
end
```

## Detection

- `StreamData.filter/2` calls in property tests
- `FilterTooNarrowError` appearing in CI logs
- Generators that filter for specific subsets: only even, only positive, only valid emails

## Bad

```elixir
property "even numbers are divisible by 2" do
  check all n <- StreamData.filter(StreamData.integer(), &(rem(&1, 2) == 0)) do
    assert rem(n, 2) == 0
  end
end

property "list with at least one element" do
  check all list <- StreamData.filter(
                      StreamData.list_of(StreamData.integer()),
                      &(length(&1) > 0)
                    ) do
    assert length(list) >= 1
  end
end
```

## Good

```elixir
property "even numbers are divisible by 2" do
  # Generate only even numbers by mapping: multiply any integer by 2
  check all n <- StreamData.map(StreamData.integer(), &(&1 * 2)) do
    assert rem(n, 2) == 0
  end
end

property "list with at least one element" do
  # Use nonempty/1 — generates lists of length >= 1, zero rejection
  check all list <- StreamData.nonempty(StreamData.list_of(StreamData.integer())) do
    assert length(list) >= 1
  end
end
```

## Useful constructive alternatives

| You want | Use instead of filter |
|----------|----------------------|
| Even integers | `map(integer(), &(&1 * 2))` |
| Positive integers | `positive_integer()` |
| Non-negative integers | `non_negative_integer()` |
| Non-empty list | `nonempty(list_of(term))` |
| Non-empty string | `string(:ascii, min_length: 1)` |
| Integer in range | `integer(1..100)` |
| One of a set | `member_of([:a, :b, :c])` |

## When filter is acceptable

Use `filter/2` only when the rejection rate is very low — for example, filtering
a list of strings to exclude one specific value:

```elixir
# Low rejection rate — acceptable
check all s <- StreamData.filter(StreamData.string(:ascii), &(&1 != "reserved")) do
  ...
end
```

## Further Reading

- [StreamData.filter/2 docs](https://hexdocs.pm/stream_data/StreamData.html#filter/2)
- [StreamData.map/2 docs](https://hexdocs.pm/stream_data/StreamData.html#map/2)
