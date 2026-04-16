# EXPECTED: passes
# BAD PRACTICE: Two anonymous setup blocks — the second one invisibly depends on
# the first, and both must be understood together to know what context is available.
Mix.install([])

ExUnit.start(autorun: true)

defmodule SetupCompositionBadTest do
  use ExUnit.Case, async: true

  setup do
    user = %{id: 1, name: "Alice"}
    %{user: user}
  end

  describe "with an account" do
    # This nested setup silently stacks on top of the outer setup.
    # You must know ExUnit's execution order to understand what %{user:, account:} contains.
    setup do
      account = %{id: 99, owner_id: 1}
      %{account: account}
    end

    test "account owner id matches user id", %{user: user, account: account} do
      assert account.owner_id == user.id
    end
  end

  describe "user alone" do
    test "user has a name", %{user: user} do
      assert is_binary(user.name)
    end
  end
end
