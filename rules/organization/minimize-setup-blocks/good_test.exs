# EXPECTED: passes
# Demonstrates: inlining setup when it's used by only 1-2 tests,
# and using setup blocks only when genuinely shared across 3+ tests.
Mix.install([])

ExUnit.start(autorun: true)

defmodule MyApp.MinimizeSetupGoodTest.Accounts do
  def display_name(%{name: nil, email: email}), do: email
  def display_name(%{name: name}), do: name
  def active?(%{status: :active}), do: true
  def active?(_), do: false
  def admin?(%{role: :admin}), do: true
  def admin?(_), do: false
  def permissions(%{role: :admin}), do: [:read, :write, :delete]
  def permissions(%{role: :editor}), do: [:read, :write]
  def permissions(_), do: [:read]
end

defmodule MyApp.MinimizeSetupGoodTest do
  use ExUnit.Case, async: true

  alias MyApp.MinimizeSetupGoodTest.Accounts

  # GOOD: Inline setup — each test shows exactly what it needs
  test "display_name falls back to email when name is nil" do
    user = %{id: 1, email: "alice@example.com", name: nil}
    assert Accounts.display_name(user) == "alice@example.com"
  end

  test "display_name returns name when present" do
    user = %{id: 2, email: "bob@example.com", name: "Bob"}
    assert Accounts.display_name(user) == "Bob"
  end

  test "active? is false for suspended user" do
    user = %{status: :suspended}
    refute Accounts.active?(user)
  end

  # GOOD: setup IS appropriate here — 3 tests share the same admin user setup
  describe "admin user" do
    setup do
      # Shared setup for 3 tests — justified
      admin = %{id: 99, email: "admin@example.com", role: :admin, status: :active}
      {:ok, admin: admin}
    end

    test "is active", %{admin: admin} do
      assert Accounts.active?(admin)
    end

    test "is flagged as admin", %{admin: admin} do
      assert Accounts.admin?(admin)
    end

    test "has full permissions", %{admin: admin} do
      assert Accounts.permissions(admin) == [:read, :write, :delete]
    end
  end
end
