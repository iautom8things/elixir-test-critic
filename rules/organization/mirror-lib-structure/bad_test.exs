# EXPECTED: passes
# BAD PRACTICE: Test files that don't mirror the lib/ structure.
# The test module name doesn't match the source module path,
# multiple modules are tested together, and naming conventions are inconsistent.
Mix.install([])

ExUnit.start(autorun: true)

# Source modules that live deep in lib/ (e.g., lib/my_app/accounts/user.ex,
# lib/my_app/accounts/session.ex)
defmodule MyApp.Accounts.UserBadSrc do
  defstruct [:id, :email, :name]
  def new(attrs), do: struct(__MODULE__, attrs)
  def display_name(%{name: n, email: e}), do: n || e
end

defmodule MyApp.Accounts.SessionBadSrc do
  def create(user_id), do: %{token: "tok_#{user_id}", user_id: user_id}
  def valid?(%{token: "tok_" <> _}), do: true
  def valid?(_), do: false
end

# BAD: This test module:
# 1. Is named "AuthTests" — doesn't correspond to any source module
# 2. Tests TWO unrelated modules in one file
# 3. Would live at test/auth_tests.exs — not mirroring lib/ structure
defmodule AuthTests do
  use ExUnit.Case, async: true

  # Testing User in a file called "auth_tests" — wrong location, wrong name
  test "user display name falls back to email" do
    user = MyApp.Accounts.UserBadSrc.new(%{email: "bob@example.com", name: nil})
    assert MyApp.Accounts.UserBadSrc.display_name(user) == "bob@example.com"
  end

  # Testing Session in the same file — should be in session_test.exs
  test "session is valid when token is present" do
    session = MyApp.Accounts.SessionBadSrc.create(1)
    assert MyApp.Accounts.SessionBadSrc.valid?(session)
  end

  test "session is invalid for empty token" do
    refute MyApp.Accounts.SessionBadSrc.valid?(%{token: "bad"})
  end
end
