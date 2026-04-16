# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP004.SimpleKV do
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, %{}, opts)

  def put(name_or_pid, key, value), do: GenServer.call(name_or_pid, {:put, key, value})
  def get(name_or_pid, key), do: GenServer.call(name_or_pid, {:get, key})

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:put, key, value}, _from, state), do: {:reply, :ok, Map.put(state, key, value)}
  def handle_call({:get, key}, _from, state), do: {:reply, Map.get(state, key), state}
end

defmodule OTP004.UniqueNamesGoodTest do
  use ExUnit.Case, async: true

  setup do
    # Unique name per test invocation — safe for concurrent async tests
    name = :"kv_#{System.unique_integer([:positive])}"
    {:ok, pid} = GenServer.start_link(OTP004.SimpleKV, %{}, name: name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{store: name}
  end

  test "stores and retrieves a value by key", %{store: store} do
    OTP004.SimpleKV.put(store, :greeting, "hello")
    assert OTP004.SimpleKV.get(store, :greeting) == "hello"
  end

  test "returns nil for unknown key", %{store: store} do
    assert OTP004.SimpleKV.get(store, :missing) == nil
  end

  test "overwrites existing key", %{store: store} do
    OTP004.SimpleKV.put(store, :x, "first")
    OTP004.SimpleKV.put(store, :x, "second")
    assert OTP004.SimpleKV.get(store, :x) == "second"
  end
end
