# EXPECTED: passes
# BAD PRACTICE: Uses :sys.get_state/1 to assert on internal GenServer state.
# These tests will break if the internal map structure changes (e.g., wrapping
# entries in a struct, adding metadata fields), even when observable behaviour
# is identical. Tests are also harder to read because readers must understand
# the internal state shape to understand what is being asserted.
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP002Bad.Cache do
  use GenServer

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, %{entries: %{}, hits: 0}, opts)
  def put(pid, key, value), do: GenServer.call(pid, {:put, key, value})
  def get(pid, key), do: GenServer.call(pid, {:get, key})

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:put, key, value}, _from, state) do
    {:reply, :ok, put_in(state, [:entries, key], value)}
  end

  def handle_call({:get, key}, _from, state) do
    value = get_in(state, [:entries, key])
    {:reply, value, %{state | hits: state.hits + 1}}
  end
end

defmodule OTP002Bad.CacheTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = GenServer.start_link(OTP002Bad.Cache, %{entries: %{}, hits: 0})
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{cache: pid}
  end

  test "put stores value in internal state map", %{cache: cache} do
    OTP002Bad.Cache.put(cache, :name, "Alice")
    # Directly inspecting internal state — brittle if state shape changes
    state = :sys.get_state(cache)
    assert state.entries[:name] == "Alice"
  end

  test "hit counter increments on get", %{cache: cache} do
    OTP002Bad.Cache.put(cache, :k, "v")
    OTP002Bad.Cache.get(cache, :k)
    # Asserting on internal bookkeeping that has no public API surface
    state = :sys.get_state(cache)
    assert state.hits == 1
  end

  test "entries map has correct size after two puts", %{cache: cache} do
    OTP002Bad.Cache.put(cache, :a, 1)
    OTP002Bad.Cache.put(cache, :b, 2)
    state = :sys.get_state(cache)
    # Instead of calling a size/1 API, reaches into internal state
    assert map_size(state.entries) == 2
  end
end
