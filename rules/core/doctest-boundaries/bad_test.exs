# EXPECTED: passes
# BAD PRACTICE: Doctest on a function with side effects. In this demo the "side effect"
# is just a counter stored in a module attribute (simulated via Process dictionary),
# but the point is that the doctest example output is non-deterministic or depends on
# external state. Real examples would use Repo.insert, HTTP clients, etc.
Mix.install([])

ExUnit.start(autorun: true)

defmodule DoctestBoundariesImpure do
  @doc """
  Returns a unique sequential ID. (Impure — depends on call count)

  This doctest is misleading: the result depends on how many times
  the function has been called before in this VM session.

      iex> DoctestBoundariesImpure.next_id()
      1
  """
  def next_id do
    count = Process.get(:doctest_counter, 0) + 1
    Process.put(:doctest_counter, count)
    count
  end
end

defmodule DoctestBoundariesBadTest do
  use ExUnit.Case, async: true

  # The doctest for next_id/0 will only pass on the first call in this process.
  # On subsequent runs or in different call orders, it returns 2, 3, etc.
  # We skip the actual doctest here to avoid a hard failure, but in a real
  # codebase, doctest DoctestBoundariesImpure would be called and would fail
  # intermittently.

  test "demonstrates the problem with impure doctests" do
    # First call returns 1 (doctest expects 1), second returns 2 — doctest breaks
    assert DoctestBoundariesImpure.next_id() == 1
    assert DoctestBoundariesImpure.next_id() == 2
    # Running doctest here would fail: expected 1, got 3
  end
end
