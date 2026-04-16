# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule TestNamingGoodTest do
  use ExUnit.Case, async: true

  describe "Integer.parse/1" do
    test "returns {integer, remainder} when string starts with digits" do
      assert Integer.parse("42abc") == {42, "abc"}
    end

    test "returns :error when string contains no leading digits" do
      assert Integer.parse("abc") == :error
    end

    test "returns {integer, empty string} when entire string is a number" do
      assert Integer.parse("100") == {100, ""}
    end
  end
end
