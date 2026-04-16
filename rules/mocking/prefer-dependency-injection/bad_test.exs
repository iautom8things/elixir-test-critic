# EXPECTED: passes
# BAD PRACTICE: Reads the storage adapter from Application.get_env at call time.
# Tests must use Application.put_env to swap in a test implementation, which:
# 1. Mutates global state — not safe for async: true tests
# 2. Requires careful cleanup (on_exit) to restore original state
# 3. Hides the dependency from function signatures
Mix.install([])

ExUnit.start(autorun: true)

defmodule MOCK007Bad.FakeStorage do
  # Simple in-process store for testing
  def save(key, value) do
    :ets.insert(:mock007_bad_store, {key, value})
    :ok
  end

  def fetch(key) do
    case :ets.lookup(:mock007_bad_store, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end
end

defmodule MOCK007Bad.UserCache do
  # Reads adapter from global application config — hidden dependency
  def cache_user(user_id, user_data) do
    adapter = Application.get_env(:mock007_bad, :storage_adapter)
    adapter.save("user:#{user_id}", user_data)
  end

  def get_user(user_id) do
    adapter = Application.get_env(:mock007_bad, :storage_adapter)
    adapter.fetch("user:#{user_id}")
  end
end

defmodule MOCK007Bad.DependencyInjectionBadTest do
  # NOTE: async: false because Application.put_env is NOT async-safe
  use ExUnit.Case, async: false

  setup do
    # Must set global config and clean it up — boilerplate for every test
    original = Application.get_env(:mock007_bad, :storage_adapter)
    Application.put_env(:mock007_bad, :storage_adapter, MOCK007Bad.FakeStorage)

    :ets.new(:mock007_bad_store, [:named_table, :public])

    on_exit(fn ->
      if original do
        Application.put_env(:mock007_bad, :storage_adapter, original)
      else
        Application.delete_env(:mock007_bad, :storage_adapter)
      end
      try do
        :ets.delete(:mock007_bad_store)
      rescue
        ArgumentError -> :ok
      end
    end)
  end

  test "cache_user saves via global config adapter" do
    # Works, but forces sequential tests and pollutes application env
    assert :ok == MOCK007Bad.UserCache.cache_user(1, %{name: "Alice"})
  end

  test "get_user retrieves via global config adapter" do
    MOCK007Bad.UserCache.cache_user(2, %{name: "Bob"})
    assert {:ok, %{name: "Bob"}} == MOCK007Bad.UserCache.get_user(2)
  end
end
