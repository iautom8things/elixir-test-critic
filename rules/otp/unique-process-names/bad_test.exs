# EXPECTED: passes
# BAD PRACTICE: Registers the GenServer under a hardcoded atom name (:kv_store).
# In a real test suite with async: true, two tests running concurrently will
# both try to register :kv_store and one will fail with {:already_started, pid}.
# This passes here only because we run tests sequentially in this script, but
# it is a latent flakiness bug in any async test suite.
Mix.install([])

ExUnit.start(autorun: true)

defmodule OTP004Bad.SimpleKV do
  use GenServer

  def start_link(opts \\ [name: :kv_store]),
    do: GenServer.start_link(__MODULE__, %{}, opts)

  def put(key, value), do: GenServer.call(:kv_store, {:put, key, value})
  def get(key), do: GenServer.call(:kv_store, {:get, key})

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:put, key, value}, _from, state), do: {:reply, :ok, Map.put(state, key, value)}
  def handle_call({:get, key}, _from, state), do: {:reply, Map.get(state, key), state}
end

defmodule OTP004Bad.UniqueNamesBadTest do
  # NOTE: async: false here because the hardcoded name WILL cause conflicts
  # if async: true is used with multiple tests. That's exactly the problem.
  use ExUnit.Case, async: false

  setup do
    # Fixed atom name — every test in this module competes for :kv_store
    {:ok, pid} = GenServer.start_link(OTP004Bad.SimpleKV, %{}, name: :kv_store)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    :ok
  end

  test "stores a value (would fail if async: true and tests run concurrently)" do
    OTP004Bad.SimpleKV.put(:greeting, "hello")
    assert OTP004Bad.SimpleKV.get(:greeting) == "hello"
  end

  test "another test also uses :kv_store (safe here due to async: false)" do
    OTP004Bad.SimpleKV.put(:key, "value")
    assert OTP004Bad.SimpleKV.get(:key) == "value"
  end
end
