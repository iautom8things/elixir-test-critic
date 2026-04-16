# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule SetupCompositionGoodTest do
  use ExUnit.Case, async: true

  setup :create_user

  describe "with an account" do
    setup :create_account

    test "account belongs to user", %{user: user, account: account} do
      assert account.owner_id == user.id
    end
  end

  describe "user alone" do
    test "user has a name", %{user: user} do
      assert is_binary(user.name)
    end
  end

  defp create_user(_context) do
    %{user: %{id: 1, name: "Alice"}}
  end

  defp create_account(%{user: user}) do
    %{account: %{id: 99, owner_id: user.id}}
  end
end
