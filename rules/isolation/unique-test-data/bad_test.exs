# EXPECTED: failure
# BAD PRACTICE: Hardcoded email used in two tests that share a store.
# The second test fails with {:error, :email_taken} because the first test
# already inserted "alice@example.com". In real codebases this happens with
# a shared database and no rollback between tests.
Mix.install([])

ExUnit.start(autorun: true)

defmodule UniqueTestDataBadSharedStore do
  use Agent

  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)

  def insert(attrs) do
    email = attrs[:email]
    records = Agent.get(__MODULE__, & &1)
    if Enum.any?(records, &(&1.email == email)) do
      {:error, :email_taken}
    else
      Agent.update(__MODULE__, &[%{email: email} | &1])
      {:ok, %{email: email}}
    end
  end
end

defmodule UniqueTestDataBadTest do
  use ExUnit.Case

  setup_all do
    start_supervised!(UniqueTestDataBadSharedStore)
    :ok
  end

  # Both tests hardcode the same email — one of them will fail
  test "creates user alice (first test)" do
    assert {:ok, _user} = UniqueTestDataBadSharedStore.insert(%{email: "alice@example.com"})
  end

  test "creates user alice (second test — fails due to hardcoded email)" do
    # In a real codebase this also asserts {:ok, _}, but gets {:error, :email_taken}
    assert {:ok, _user} = UniqueTestDataBadSharedStore.insert(%{email: "alice@example.com"})
  end
end
