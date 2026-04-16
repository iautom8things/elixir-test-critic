# Property-Based Testing Rules

Rules for using StreamData and property-based testing effectively in Elixir.

Property-based testing generates many random inputs and checks that a property
(invariant) holds for all of them. It is most powerful when you can express a
general truth about your function's output — for example, "the result is always
non-negative" or "decode(encode(x)) == x for any x". It complements rather than
replaces example-based tests.

## Rules in this category

| ID | Rule | Severity |
|----|------|----------|
| [ETC-PROP-001](when-to-use-properties/) | Use property tests for invariants, examples for specifics | recommendation |
| [ETC-PROP-002](roundtrip-properties/) | Test encode/decode with roundtrip properties | recommendation |
| [ETC-PROP-003](prefer-map-over-filter/) | Prefer map over filter in generators | warning |
| [ETC-PROP-004](dont-reimplement-sut/) | Don't reimplement the system under test in properties | warning |

## Setup

```elixir
# mix.exs
{:stream_data, "~> 1.0", only: [:test, :dev]}
```

```elixir
# In test files
use ExUnitProperties
```

## Core patterns

**Roundtrip** — `decode(encode(x)) == x` for all valid `x`. The most productive
single pattern: catches Unicode, empty input, and boundary value bugs.

**Invariant** — a property of the output that holds regardless of exact input:
range bounds, ordering, structural preservation, monotonicity.

**Constructive generation** — use `map/2`, `bind/2`, and built-in constrained
generators (`positive_integer/0`, `nonempty/1`, `integer(1..100)`) instead of
`filter/2` to avoid `FilterTooNarrowError`.

## Common generators

```elixir
StreamData.integer()                    # any integer
StreamData.positive_integer()           # > 0
StreamData.non_negative_integer()       # >= 0
StreamData.integer(1..100)             # bounded range
StreamData.float()                      # any float
StreamData.string(:ascii)              # ASCII string
StreamData.string(:printable)          # printable Unicode
StreamData.string(:utf8)               # any valid UTF-8
StreamData.binary()                    # any binary
StreamData.boolean()                   # true | false
StreamData.atom(:alphanumeric)         # atom from alphanumeric chars
StreamData.list_of(gen)                # list of values from gen
StreamData.nonempty(list_of(gen))      # non-empty list
StreamData.map_of(key_gen, val_gen)    # map
StreamData.member_of([:a, :b, :c])    # one of the given values
StreamData.one_of([gen1, gen2])        # one of the given generators
StreamData.map(gen, fun)               # transform generated values
StreamData.bind(gen, fun)              # flatMap / dependent generation
```
