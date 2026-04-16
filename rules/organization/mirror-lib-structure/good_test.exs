# EXPECTED: passes
# Demonstrates: test file at test/my_app/accounts/user_test.exs
# corresponding to lib/my_app/accounts/user.ex
# The module name and test file path match the source structure.
Mix.install([])

ExUnit.start(autorun: true)

# Represents: lib/my_app/accounts/user.ex
defmodule MyApp.Accounts.User do
  defstruct [:id, :email, :name]

  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  def display_name(%__MODULE__{name: name, email: email}) do
    name || email
  end
end

# Represents: test/my_app/accounts/user_test.exs
# The test module and file path mirror the source module and file path.
defmodule MyApp.Accounts.UserTest do
  use ExUnit.Case, async: true

  alias MyApp.Accounts.User

  describe "new/1" do
    test "creates a user struct from attributes" do
      user = User.new(%{id: 1, email: "alice@example.com", name: "Alice"})
      assert user.id == 1
      assert user.email == "alice@example.com"
    end
  end

  describe "display_name/1" do
    test "returns name when set" do
      user = User.new(%{email: "alice@example.com", name: "Alice"})
      assert User.display_name(user) == "Alice"
    end

    test "falls back to email when name is nil" do
      user = User.new(%{email: "alice@example.com", name: nil})
      assert User.display_name(user) == "alice@example.com"
    end
  end
end
