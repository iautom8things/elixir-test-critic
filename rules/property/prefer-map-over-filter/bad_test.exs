# EXPECTED: passes
# BAD PRACTICE: Using filter/2 with high rejection rates.
# In this file we demonstrate the pattern — the tests pass because we use
# low max_runs to avoid FilterTooNarrowError, but in real usage these would
# intermittently fail or be very slow.
Mix.install([:stream_data])

ExUnit.start(autorun: true)

defmodule MyApp.PreferMapBadTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  # BAD: filter/2 with ~50% rejection rate.
  # Real usage with default max_runs=100 will likely hit FilterTooNarrowError.
  # We use max_runs: 20 here to avoid the error in this demo, but this is the
  # pattern to avoid in production code.
  property "BAD: even numbers via filter — ~50% rejection rate" do
    check all n <-
                StreamData.filter(StreamData.integer(0..100), &(rem(&1, 2) == 0)),
              max_runs: 20 do
      assert rem(n, 2) == 0
    end
  end

  # BAD: filtering a list to ensure it's non-empty — rejection rate approaches 100%
  # for very short lists (P(empty list) is nonzero by default).
  # Use nonempty/1 or list_of with min_length instead.
  property "BAD: non-empty list via filter — can hit FilterTooNarrowError" do
    check all list <-
                StreamData.filter(
                  StreamData.list_of(StreamData.integer(), max_length: 5),
                  &(length(&1) > 0)
                ),
              max_runs: 20 do
      assert length(list) >= 1
    end
  end
end
