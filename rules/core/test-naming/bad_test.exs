# EXPECTED: passes
# BAD PRACTICE: Vague test names that don't indicate what broke when they fail.
# "works", "fails", and "edge case" give no information without reading the test body.
Mix.install([])

ExUnit.start(autorun: true)

defmodule TestNamingBadTest do
  use ExUnit.Case, async: true

  describe "Integer.parse/1" do
    # A failing "works" test tells you nothing — you have to read the body
    test "works" do
      assert Integer.parse("42abc") == {42, "abc"}
    end

    # "fails" — fails HOW? returns error? raises? the name is useless
    test "fails" do
      assert Integer.parse("abc") == :error
    end

    # "edge case" — which edge? why does it matter?
    test "edge case" do
      assert Integer.parse("100") == {100, ""}
    end
  end
end
