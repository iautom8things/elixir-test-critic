# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule ObservableAssertionGoodTest do
  use ExUnit.Case, async: true

  test "sums the line item amounts" do
    total = Enum.sum([19, 23])
    assert total == 42
  end
end
