# EXPECTED: passes
# BAD PRACTICE: No schema priming. The first test to execute a query triggers
# lazy schema compilation. In a concurrent test suite this can cause flaky
# timeouts and makes the first test reliably slower than all subsequent tests.
Mix.install([])

ExUnit.start(autorun: true)

# Simulates Absinthe's lazy schema compilation (not primed before tests)
defmodule AbsPrimeBad.SchemaRegistry do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{compiled: false, compile_count: 0} end, name: __MODULE__)
  end

  def run_query(_query) do
    Agent.get_and_update(__MODULE__, fn state ->
      if state.compiled do
        # Already compiled by a previous test — fast
        {{:ok, :already_compiled, state.compile_count}, state}
      else
        # BAD: first test triggers lazy compilation — slow, can timeout
        Process.sleep(5)  # simulate expensive compilation
        new_state = %{state | compiled: true, compile_count: state.compile_count + 1}
        {{:ok, :lazily_compiled, new_state.compile_count}, new_state}
      end
    end)
  end

  def compile_count do
    Agent.get(__MODULE__, & &1.compile_count)
  end

  def reset do
    Agent.update(__MODULE__, fn _ -> %{compiled: false, compile_count: 0} end)
  end
end

defmodule AbsPrimeBad.UnprimedSchemaTest do
  use ExUnit.Case

  setup_all do
    {:ok, _} = AbsPrimeBad.SchemaRegistry.start_link([])
    # BAD: no Absinthe.Test.prime/1 call here
    # In a real test_helper.exs the schema is never warmed up before tests run
    :ok
  end

  # Reset state so each test demonstrates the problem independently
  setup do
    AbsPrimeBad.SchemaRegistry.reset()
    :ok
  end

  test "bad: queries trigger lazy compilation — no priming means unpredictable first-hit cost" do
    # Without priming, the very first query pays the compilation cost.
    # In a real Absinthe app with a large schema, this can cause flaky timeouts.
    {:ok, status1, _} = AbsPrimeBad.SchemaRegistry.run_query("{ posts { id } }")

    # Second query may or may not need compilation depending on whether
    # the first query already triggered it. This is the core problem:
    # test behavior depends on execution order.
    {:ok, status2, _} = AbsPrimeBad.SchemaRegistry.run_query("{ users { id } }")

    # At least one of these triggered lazy compilation
    assert :lazily_compiled in [status1, status2]
    # And the second should be already compiled since we just triggered it
    assert status2 == :already_compiled
  end

  test "bad: compile count shows compilation happened during tests, not before" do
    # Force a query to ensure compilation happens
    AbsPrimeBad.SchemaRegistry.run_query("{ posts { id } }")
    # With priming, compile_count would already be 1 from setup_all.
    # Here it's 1 because a test triggered it — unpredictable timing.
    assert AbsPrimeBad.SchemaRegistry.compile_count() >= 1
  end
end
