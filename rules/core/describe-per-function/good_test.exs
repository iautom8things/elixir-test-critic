# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule DescribePerFunctionSubject do
  def double(n), do: n * 2
  def triple(n), do: n * 3
end

defmodule DescribePerFunctionGoodTest do
  use ExUnit.Case, async: true

  describe "double/1" do
    test "doubles positive numbers" do
      assert DescribePerFunctionSubject.double(4) == 8
    end

    test "doubles zero" do
      assert DescribePerFunctionSubject.double(0) == 0
    end
  end

  describe "triple/1" do
    test "triples positive numbers" do
      assert DescribePerFunctionSubject.triple(3) == 9
    end

    test "triples negative numbers" do
      assert DescribePerFunctionSubject.triple(-2) == -6
    end
  end
end
