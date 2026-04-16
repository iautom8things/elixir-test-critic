# EXPECTED: passes
# BAD PRACTICE: Named ETS table shared across all tests. In an async suite, concurrent
# tests writing to :shared_test_cache interfere with each other. This file passes
# because it runs alone, but in a real async suite with multiple test modules
# both writing to the same named table, results are non-deterministic.
Mix.install([])

ExUnit.start(autorun: true)

defmodule NoSharedEtsAsyncBadTest do
  use ExUnit.Case, async: true

  setup do
    # Named ETS table visible to all processes in the VM — global mutable state
    table = :ets.new(:shared_test_cache, [:named_table, :set, :public])
    on_exit(fn ->
      try do
        :ets.delete(table)
      rescue
        ArgumentError -> :ok
      end
    end)
    :ok
  end

  test "stores a value in the shared named table" do
    # Wrong: any concurrent test can read or overwrite :key in :shared_test_cache
    :ets.insert(:shared_test_cache, {:key, "from_test_1"})
    assert [{:key, "from_test_1"}] == :ets.lookup(:shared_test_cache, :key)
  end
end
