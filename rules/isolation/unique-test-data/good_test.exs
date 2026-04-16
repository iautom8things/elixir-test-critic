# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule UniqueTestDataGoodTest do
  use ExUnit.Case, async: true

  # Simulated in-memory store with a uniqueness constraint on :email
  defmodule FakeUserStore do
    def insert(records, attrs) do
      email = attrs[:email]
      if Enum.any?(records, &(&1.email == email)) do
        {:error, :email_taken}
      else
        {:ok, %{email: email, id: System.unique_integer([:positive])}}
      end
    end
  end

  test "two tests can insert users without collision" do
    store = []
    # Each test generates a unique email — no collision across concurrent tests
    email = "user_#{System.unique_integer([:positive])}@example.com"
    {:ok, user} = FakeUserStore.insert(store, %{email: email})
    assert user.email == email
  end

  test "second test also inserts without collision" do
    store = []
    email = "user_#{System.unique_integer([:positive])}@example.com"
    {:ok, user} = FakeUserStore.insert(store, %{email: email})
    assert user.email == email
  end
end
