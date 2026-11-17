# EXPECTED: passes
# BAD PRACTICE: no Absinthe.Test.prime/1 before the suite. The first query any
# test runs also makes the VM load Absinthe's modules, which takes several
# milliseconds. A test that expects a message inside a tight timeout pays that
# cost in its window. This script passes: the delay is small, and it only bites
# with tight timeouts on a loaded machine.
Mix.install([{:absinthe, "~> 1.7"}])

defmodule AbsPrimeBad.Schema do
  use Absinthe.Schema

  query do
    field :greeting, :string do
      resolve fn _, _, _ -> {:ok, "hello"} end
    end
  end
end

ExUnit.start(autorun: true)

defmodule AbsPrimeBad.UnprimedSchemaTest do
  use ExUnit.Case, async: true

  # BAD: nothing primed the schema, so whichever test runs first loads Absinthe.
  test "the first query loads Absinthe's code inside the receive window" do
    test_pid = self()

    spawn(fn -> send(test_pid, Absinthe.run("{ greeting }", AbsPrimeBad.Schema)) end)

    # The timeout has to cover code loading as well as the query.
    assert_receive {:ok, %{data: %{"greeting" => "hello"}}}, 5_000
  end
end
