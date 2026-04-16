# EXPECTED: passes
# BAD PRACTICE: No describe blocks — flat list of tests across multiple functions.
# When tests fail, output gives no indication of which function is broken.
Mix.install([])

ExUnit.start(autorun: true)

defmodule DescribePerFunctionBadSubject do
  def double(n), do: n * 2
  def triple(n), do: n * 3
end

defmodule DescribePerFunctionBadTest do
  use ExUnit.Case, async: true

  # All tests at the top level — no structure indicating which function each covers
  test "doubles positive numbers" do
    assert DescribePerFunctionBadSubject.double(4) == 8
  end

  test "doubles zero" do
    assert DescribePerFunctionBadSubject.double(0) == 0
  end

  test "triples positive numbers" do
    assert DescribePerFunctionBadSubject.triple(3) == 9
  end

  test "triples negative numbers" do
    assert DescribePerFunctionBadSubject.triple(-2) == -6
  end
end
