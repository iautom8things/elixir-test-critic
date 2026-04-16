# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule TestErrorTuplesStore do
  def find_user(1), do: {:ok, %{id: 1, email: "alice@example.com"}}
  def find_user(3), do: {:error, :unauthorized}
  def find_user(_), do: {:error, :not_found}
end

defmodule TestErrorTuplesGoodTest do
  use ExUnit.Case, async: true

  describe "find_user/1" do
    test "returns {:ok, user} when user exists" do
      assert {:ok, user} = TestErrorTuplesStore.find_user(1)
      assert user.email == "alice@example.com"
    end

    test "returns {:error, :not_found} when no user exists with that id" do
      # Specific reason — not just {:error, _}
      assert {:error, :not_found} = TestErrorTuplesStore.find_user(999)
    end

    test "returns {:error, :unauthorized} for restricted user id" do
      # Different error path tested independently with specific reason
      assert {:error, :unauthorized} = TestErrorTuplesStore.find_user(3)
    end
  end
end
