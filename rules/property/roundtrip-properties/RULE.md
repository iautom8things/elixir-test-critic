---
id: ETC-PROP-002
title: "Test encode/decode with roundtrip properties"
category: property
severity: recommendation
summary: >
  For any serialisation pair (encode/decode, serialize/parse, compress/decompress),
  write a property test asserting that decode(encode(x)) == x for all valid inputs.
  Roundtrip properties catch edge cases with empty strings, Unicode, special characters,
  and boundary values that example tests routinely miss.
principles:
  - boundary-testing
applies_when:
  - "Any function pair where one inverts the other: encode/decode, serialize/parse, pack/unpack"
  - "JSON serialisation of domain structs or changesets"
  - "Base64 or other binary encoding"
  - "Custom data format writers and readers"
  - "URL encoding/decoding"
does_not_apply_when:
  - "Lossy transformations where round-trip equality doesn't hold (e.g., image compression)"
  - "One-way functions (hashing, encryption without the key)"
---

# Test encode/decode with roundtrip properties

A roundtrip property expresses the core contract of any invertible transformation:
applying the forward operation followed by the inverse should return the original value.

```
decode(encode(x)) == x   for all x in the domain
```

This is one of the most productive property patterns because it works for any
serialisation-like function pair and finds bugs that example tests miss: empty
strings, strings with newlines, Unicode edge cases (null bytes, surrogate pairs,
right-to-left marks), lists of zero length, nested maps, etc.

## Problem

Example-based encode/decode tests typically check a small set of hand-picked values.
They miss the long tail of inputs that expose bugs in real-world usage — particularly
Unicode, empty collections, and values at integer boundaries.

## Detection

- `encode/1` and `decode/1` functions exist but only have example-based tests
- Tests that check `encode("hello") == "aGVsbG8="` but not the roundtrip

## Bad

```elixir
defmodule MyApp.TokenTest do
  use ExUnit.Case, async: true

  test "encodes user id" do
    assert MyApp.Token.encode(42) == "NDI="
  end

  test "decodes token back to user id" do
    assert MyApp.Token.decode("NDI=") == {:ok, 42}
  end
  # Missing: what about 0? Negative? Max integer? — example tests don't tell you.
end
```

## Good

```elixir
defmodule MyApp.TokenTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  # Keep example tests for specific known values
  test "encodes user id 42" do
    assert MyApp.Token.encode(42) == "NDI="
  end

  # Add roundtrip property to cover the full input space
  property "encode/decode roundtrip for any non-negative integer" do
    check all id <- StreamData.non_negative_integer() do
      assert {:ok, ^id} = id |> MyApp.Token.encode() |> MyApp.Token.decode()
    end
  end
end
```

## Roundtrip for strings

```elixir
property "URL encode/decode roundtrip for arbitrary strings" do
  check all s <- StreamData.string(:printable) do
    assert URI.decode(URI.encode(s)) == s
  end
end
```

## Testing the inverse direction

For a complete specification, test both directions:

```elixir
property "decode then encode returns the same encoded form" do
  check all id <- StreamData.positive_integer() do
    encoded = MyApp.Token.encode(id)
    {:ok, decoded} = MyApp.Token.decode(encoded)
    assert MyApp.Token.encode(decoded) == encoded
  end
end
```

## Further Reading

- [StreamData.string/1](https://hexdocs.pm/stream_data/StreamData.html#string/2)
- [Property-based testing patterns — roundtrip](https://fsharpforfunandprofit.com/posts/property-based-testing-2/)
