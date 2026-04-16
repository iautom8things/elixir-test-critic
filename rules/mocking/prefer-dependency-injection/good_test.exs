# EXPECTED: passes
Mix.install([:mox])

ExUnit.start(autorun: true)

defmodule MOCK007.StorageBehaviour do
  @callback save(key :: String.t(), value :: term()) :: :ok | {:error, term()}
  @callback fetch(key :: String.t()) :: {:ok, term()} | {:error, :not_found}
end

Mox.defmock(MOCK007.StorageMock, for: MOCK007.StorageBehaviour)

# Real in-memory storage implementation
defmodule MOCK007.MemoryStorage do
  @behaviour MOCK007.StorageBehaviour

  @impl true
  def save(key, value) do
    # In production: persists to a real store
    _ = {key, value}
    :ok
  end

  @impl true
  def fetch(_key), do: {:error, :not_found}
end

# Module uses dependency injection — storage is a parameter
defmodule MOCK007.UserCache do
  @default_storage MOCK007.MemoryStorage

  def cache_user(storage \\ @default_storage, user_id, user_data) do
    storage.save("user:#{user_id}", user_data)
  end

  def get_user(storage \\ @default_storage, user_id) do
    storage.fetch("user:#{user_id}")
  end
end

defmodule MOCK007.DependencyInjectionGoodTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "cache_user saves to the storage adapter" do
    # Inject the mock as an argument — no Application.put_env needed
    # Async-safe: no global state mutation
    expect(MOCK007.StorageMock, :save, 1, fn "user:42", %{name: "Alice"} -> :ok end)

    assert :ok ==
             MOCK007.UserCache.cache_user(MOCK007.StorageMock, 42, %{name: "Alice"})
  end

  test "get_user fetches from the storage adapter" do
    expect(MOCK007.StorageMock, :fetch, 1, fn "user:99" ->
      {:ok, %{name: "Bob"}}
    end)

    assert {:ok, %{name: "Bob"}} ==
             MOCK007.UserCache.get_user(MOCK007.StorageMock, 99)
  end

  test "get_user returns not_found when storage has no entry" do
    expect(MOCK007.StorageMock, :fetch, 1, fn _key -> {:error, :not_found} end)

    assert {:error, :not_found} ==
             MOCK007.UserCache.get_user(MOCK007.StorageMock, 999)
  end
end
