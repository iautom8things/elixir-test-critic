# EXPECTED: passes
# Demonstrates: the schema priming pattern for Absinthe test suites.
#
# In a real app, test/test_helper.exs should include:
#
#   ExUnit.start()
#   Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)
#   Absinthe.Test.prime(MyApp.Schema)   # <-- compile schema before any test runs
#
# Without priming, the first test to execute a query triggers lazy compilation,
# which can cause flaky timeouts in concurrent test suites.
#
# This script models the concept with a lazy-compilation simulation.
Mix.install([])

ExUnit.start(autorun: true)

# Simulates Absinthe's lazy schema compilation
defmodule AbsPrimeGood.SchemaRegistry do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{compiled: false, compile_count: 0} end, name: __MODULE__)
  end

  # prime/1 compiles synchronously before tests run
  def prime do
    Agent.update(__MODULE__, fn state ->
      Process.sleep(1)  # simulate compilation work
      %{state | compiled: true, compile_count: state.compile_count + 1}
    end)
  end

  def run_query(_query) do
    Agent.get_and_update(__MODULE__, fn state ->
      if state.compiled do
        # Schema already compiled — fast path
        {{:ok, :already_compiled, state.compile_count}, state}
      else
        # First call triggers lazy compilation — slow path
        Process.sleep(5)  # simulate expensive compilation
        new_state = %{state | compiled: true, compile_count: state.compile_count + 1}
        {{:ok, :lazily_compiled, new_state.compile_count}, new_state}
      end
    end)
  end

  def compiled? do
    Agent.get(__MODULE__, & &1.compiled)
  end

  def compile_count do
    Agent.get(__MODULE__, & &1.compile_count)
  end
end

defmodule AbsPrimeGood.PrimedSchemaTest do
  use ExUnit.Case

  setup_all do
    {:ok, _} = AbsPrimeGood.SchemaRegistry.start_link([])

    # GOOD: prime the schema before any test runs (models test_helper.exs prime call)
    AbsPrimeGood.SchemaRegistry.prime()
    :ok
  end

  test "schema is already compiled when first test runs" do
    assert AbsPrimeGood.SchemaRegistry.compiled?()
  end

  test "first query does not trigger compilation — uses pre-compiled schema" do
    assert {:ok, :already_compiled, _} =
             AbsPrimeGood.SchemaRegistry.run_query("{ posts { id } }")
  end

  test "second query also uses pre-compiled schema" do
    assert {:ok, :already_compiled, _} =
             AbsPrimeGood.SchemaRegistry.run_query("{ users { id } }")
  end

  test "schema compiled exactly once — during priming, not during tests" do
    # The compile count should be 1 (from prime/0 in setup_all),
    # not higher (which would indicate lazy re-compilation during tests)
    assert AbsPrimeGood.SchemaRegistry.compile_count() == 1
  end
end
