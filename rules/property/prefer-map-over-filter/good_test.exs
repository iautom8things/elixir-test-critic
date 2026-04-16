# EXPECTED: passes
Mix.install([:stream_data])

ExUnit.start(autorun: true)

defmodule MyApp.PreferMapGoodTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  # GOOD: map/2 constructs even numbers directly — zero rejection
  property "even numbers via map are divisible by 2" do
    check all n <- StreamData.map(StreamData.integer(), &(&1 * 2)) do
      assert rem(n, 2) == 0
    end
  end

  # GOOD: nonempty/1 generates non-empty lists without any rejection
  property "nonempty list always has at least one element" do
    check all list <- StreamData.nonempty(StreamData.list_of(StreamData.integer())) do
      assert length(list) >= 1
    end
  end

  # GOOD: integer/1 with range — generates only values in 1..100, no filtering needed
  property "integers in range are always within bounds" do
    check all n <- StreamData.integer(1..100) do
      assert n >= 1
      assert n <= 100
    end
  end

  # GOOD: positive_integer/0 — never negative or zero, zero rejection
  property "positive_integer is always > 0" do
    check all n <- StreamData.positive_integer() do
      assert n > 0
    end
  end

  # GOOD: string with min_length generates only non-empty strings
  property "non-empty string has length >= 1" do
    check all s <- StreamData.string(:ascii, min_length: 1) do
      assert String.length(s) >= 1
    end
  end

  # GOOD: member_of picks from an explicit valid set — no filtering needed
  property "member_of only produces values from the given list" do
    valid = [:alpha, :beta, :gamma]

    check all tier <- StreamData.member_of(valid) do
      assert tier in valid
    end
  end
end
