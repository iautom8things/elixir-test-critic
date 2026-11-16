# EXPECTED: passes
# Demonstrates: priming Absinthe before the suite runs.
#
# In a real app, test/test_helper.exs includes:
#
#   ExUnit.start()
#   Absinthe.Test.prime(MyApp.Schema)
#
# prime/1 runs the introspection query once. That makes the VM load most of
# Absinthe's modules up front, so no test pays for code loading inside a
# timing-sensitive assertion.
Mix.install([{:absinthe, "~> 1.7"}])

defmodule AbsPrimeGood.Schema do
  use Absinthe.Schema

  query do
    field :greeting, :string do
      resolve fn _, _, _ -> {:ok, "hello"} end
    end
  end
end

ExUnit.start(autorun: false)

# GOOD: what test_helper.exs does, before any test runs.
:ok = Absinthe.Test.prime(AbsPrimeGood.Schema)

defmodule AbsPrimeGood.PrimedSchemaTest do
  use ExUnit.Case, async: true

  test "a query runs against the primed schema" do
    assert {:ok, %{data: %{"greeting" => "hello"}}} =
             Absinthe.run("{ greeting }", AbsPrimeGood.Schema)
  end

  test "a query result arrives inside a short receive timeout" do
    test_pid = self()

    spawn(fn -> send(test_pid, Absinthe.run("{ greeting }", AbsPrimeGood.Schema)) end)

    # Absinthe's code is already loaded, so the timeout only has to cover the query.
    assert_receive {:ok, %{data: %{"greeting" => "hello"}}}, 500
  end
end

ExUnit.run()
