# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule AssertRaiseWithMessageSubject do
  def process(n) when is_integer(n) and n > 0, do: n * 2
  def process(n) when is_integer(n), do: raise ArgumentError, "expected a positive integer, got: #{n}"
  def process(_), do: raise ArgumentError, "expected an integer"
end

defmodule AssertRaiseWithMessageGoodTest do
  use ExUnit.Case, async: true

  describe "process/1" do
    test "raises with specific message when given a negative integer" do
      # 3-arity: verifies both the exception type AND the reason
      assert_raise ArgumentError, ~r/expected a positive integer/, fn ->
        AssertRaiseWithMessageSubject.process(-1)
      end
    end

    test "raises with different message when given a non-integer" do
      assert_raise ArgumentError, "expected an integer", fn ->
        AssertRaiseWithMessageSubject.process("oops")
      end
    end
  end
end
