# EXPECTED: passes
# BAD PRACTICE: Broad setup block that runs for all tests, even those that don't
# use the setup context. Forces readers to check setup when reading each test.
Mix.install([])

ExUnit.start(autorun: true)

defmodule MyApp.MinimizeSetupBadTest.Accounts do
  def display_name(%{name: nil, email: email}), do: email
  def display_name(%{name: name}), do: name
  def active?(%{status: :active}), do: true
  def active?(_), do: false
end

defmodule MyApp.MinimizeSetupBadTest do
  use ExUnit.Case, async: true

  alias MyApp.MinimizeSetupBadTest.Accounts

  # BAD: setup provides a user, but only 1 of the 4 tests actually uses it.
  # Every reader must scan up to setup to understand each test, even when
  # the test doesn't use the context.
  setup do
    user = %{id: 1, email: "alice@example.com", name: nil}
    {:ok, user: user}
  end

  test "display_name falls back to email", %{user: user} do
    # Only this test uses `user` from setup
    assert Accounts.display_name(user) == "alice@example.com"
  end

  test "active? is true for active status", _context do
    # BAD: Doesn't use context — creates its own user inline anyway
    # Reader must still check setup to know this test ignores it
    different_user = %{status: :active}
    assert Accounts.active?(different_user)
  end

  test "active? is false for suspended status", _context do
    # BAD: Also ignores setup context entirely
    suspended_user = %{status: :suspended}
    refute Accounts.active?(suspended_user)
  end

  test "display_name returns name when present", _context do
    # BAD: Creates its own user with a name — setup user has name: nil, useless here
    named_user = %{id: 2, email: "bob@example.com", name: "Bob"}
    assert Accounts.display_name(named_user) == "Bob"
  end
end
