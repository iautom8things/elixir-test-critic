# EXPECTED: passes
# BAD PRACTICE: Compare the result with itself, so a wrong total still passes.
Mix.install([])

ExUnit.start(autorun: true)

defmodule ObservableAssertionBadTest do
  use ExUnit.Case, async: true

  test "sums the line item amounts" do
    total = Enum.sum([19, 23])
    assert total == total
  end
end
