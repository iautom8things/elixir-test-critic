# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule NoSharedEtsAsyncGoodTest do
  use ExUnit.Case, async: true

  setup do
    # Per-test ETS table with a unique reference name — not shared across tests.
    # ETS tables are automatically deleted when the owning (test) process exits.
    table = :ets.new(:"test_cache_#{System.unique_integer([:positive])}", [:set, :public])
    %{table: table}
  end

  test "stores and retrieves a value in isolated ETS table", %{table: table} do
    :ets.insert(table, {:user_id, 42})
    assert [{:user_id, 42}] == :ets.lookup(table, :user_id)
  end

  test "empty table has no entries", %{table: table} do
    assert [] == :ets.lookup(table, :missing_key)
  end
end
