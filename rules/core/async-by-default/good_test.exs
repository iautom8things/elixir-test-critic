# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule AsyncByDefaultGoodTest do
  use ExUnit.Case, async: true

  test "pure function test runs concurrently" do
    assert String.upcase("hello") == "HELLO"
  end

  test "data transformation runs concurrently" do
    result = Enum.map([1, 2, 3], &(&1 * 2))
    assert result == [2, 4, 6]
  end
end
