# EXPECTED: passes
# BAD PRACTICE: 2-arity assert_raise checks only the exception type, not the reason.
# This test passes even when the wrong code path raises ArgumentError.
# Notice that both tests pass despite testing different code paths — you cannot
# distinguish which ArgumentError was raised.
Mix.install([])

ExUnit.start(autorun: true)

defmodule AssertRaiseWithMessageBadSubject do
  def process(n) when is_integer(n) and n > 0, do: n * 2
  def process(n) when is_integer(n), do: raise ArgumentError, "expected a positive integer, got: #{n}"
  def process(_), do: raise ArgumentError, "expected an integer"
end

defmodule AssertRaiseWithMessageBadTest do
  use ExUnit.Case, async: true

  describe "process/1" do
    test "raises for negative integer (no message check)" do
      # Wrong: passes for ANY ArgumentError — the wrong code path could raise it
      assert_raise ArgumentError, fn ->
        AssertRaiseWithMessageBadSubject.process(-1)
      end
    end

    test "raises for non-integer (no message check)" do
      # Wrong: same — both tests are indistinguishable from each other
      assert_raise ArgumentError, fn ->
        AssertRaiseWithMessageBadSubject.process("oops")
      end
    end

    test "demonstrates the false positive: different code path, same assertion" do
      # This test shows that 2-arity assert_raise would also pass if process/1 raised
      # ArgumentError for a completely different reason — the message check is missing.
      assert_raise ArgumentError, fn ->
        # Even if the wrong code path raised, this assertion cannot detect it
        AssertRaiseWithMessageBadSubject.process(0)
      end
    end
  end
end
