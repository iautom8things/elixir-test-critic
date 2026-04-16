# EXPECTED: passes
# BAD PRACTICE: Only the happy path is tested. The error path is completely missing.
# Also demonstrates overly-broad {:error, _} matching which doesn't verify the reason.
Mix.install([])

ExUnit.start(autorun: true)

defmodule TestErrorTuplesBadStore do
  def find_user(1), do: {:ok, %{id: 1, email: "alice@example.com"}}
  def find_user(3), do: {:error, :unauthorized}
  def find_user(_), do: {:error, :not_found}
end

defmodule TestErrorTuplesBadTest do
  use ExUnit.Case, async: true

  describe "find_user/1" do
    test "returns the user" do
      # Only the happy path — error paths for :not_found and :unauthorized are untested
      assert {:ok, user} = TestErrorTuplesBadStore.find_user(1)
      assert user.email == "alice@example.com"
    end

    test "returns error for unknown id (overly broad match)" do
      # Wrong: {:error, _} doesn't distinguish :not_found from :unauthorized or any
      # other error. A refactoring that changes the error reason won't be caught.
      assert {:error, _} = TestErrorTuplesBadStore.find_user(999)
    end

    # Missing: no test for {:error, :unauthorized} path at all
  end
end
