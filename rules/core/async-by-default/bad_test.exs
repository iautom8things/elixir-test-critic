# EXPECTED: passes
# BAD PRACTICE: Missing async: true — these tests run sequentially for no reason.
# ExUnit cannot detect this; it just silently slows your suite and hides coupling.
Mix.install([])

ExUnit.start(autorun: true)

defmodule AsyncByDefaultBadTest do
  use ExUnit.Case   # no async: true

  test "pure function test — sequentially for no reason" do
    assert String.upcase("hello") == "HELLO"
  end

  test "another sequential test that has no shared state" do
    result = Enum.map([1, 2, 3], &(&1 * 2))
    assert result == [2, 4, 6]
  end
end
