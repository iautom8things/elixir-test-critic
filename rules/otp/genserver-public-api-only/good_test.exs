# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP002.Cache do
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, %{}, opts)

  def put(pid, key, value), do: GenServer.call(pid, {:put, key, value})
  def get(pid, key), do: GenServer.call(pid, {:get, key})
  def delete(pid, key), do: GenServer.call(pid, {:delete, key})
  def size(pid), do: GenServer.call(pid, :size)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    {:reply, :ok, Map.put(state, key, value)}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:delete, key}, _from, state) do
    {:reply, :ok, Map.delete(state, key)}
  end

  def handle_call(:size, _from, state) do
    {:reply, map_size(state), state}
  end
end

defmodule OTP002.CacheTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = GenServer.start_link(OTP002.Cache, %{})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{cache: pid}
  end

  test "put stores a value retrievable via get", %{cache: cache} do
    OTP002.Cache.put(cache, :name, "Alice")
    # Assert through the public API — internal representation is irrelevant
    assert OTP002.Cache.get(cache, :name) == "Alice"
  end

  test "get returns nil for missing key", %{cache: cache} do
    assert OTP002.Cache.get(cache, :missing) == nil
  end

  test "delete removes a key", %{cache: cache} do
    OTP002.Cache.put(cache, :temp, "data")
    OTP002.Cache.delete(cache, :temp)
    assert OTP002.Cache.get(cache, :temp) == nil
  end

  test "size reflects number of stored entries", %{cache: cache} do
    assert OTP002.Cache.size(cache) == 0
    OTP002.Cache.put(cache, :a, 1)
    OTP002.Cache.put(cache, :b, 2)
    assert OTP002.Cache.size(cache) == 2
  end
end
