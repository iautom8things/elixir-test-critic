# EXPECTED: passes
# BAD PRACTICE: The factory uses a hardcoded email "user@test.com".
# In this sequential script the two calls succeed because each test gets a
# rolled-back sandbox connection. BUT in a real async test suite both tests would
# share the same email and the second insert would fail with a unique constraint error.
# The test is written to demonstrate the structural problem, not to actually collide.
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)

Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS bad_factory_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    name TEXT,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
end)

Ecto.Adapters.SQL.Sandbox.checkin(TestCritic.Repo)

ExUnit.start(autorun: false)

defmodule BadFactory.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bad_factory_users" do
    field :email, :string
    field :name, :string
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name])
    |> validate_required([:email])
    |> unique_constraint(:email)
  end
end

defmodule BadFactory.Fixtures do
  alias TestCritic.Repo
  alias BadFactory.User

  # BAD: hardcoded email — will collide when two async tests call this simultaneously
  def user_fixture do
    Repo.insert!(User.changeset(%User{}, %{
      email: "user@test.com",
      name: "Test User"
    }))
  end
end

defmodule UniqueFactoryValuesBadTest do
  use ExUnit.Case, async: false

  import BadFactory.Fixtures
  alias TestCritic.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # In sequential mode these pass. With async: true and a shared schema,
  # calling user_fixture() in two concurrent tests would cause:
  #   ** (Ecto.ConstraintError) unique constraint "bad_factory_users_email_index" violated
  test "creates a user (sequential — works only because sandbox rolls back between tests)" do
    user = user_fixture()
    assert user.email == "user@test.com"
  end

  test "creates another user — hardcoded email is the problem" do
    # This works sequentially. Async = collision waiting to happen.
    user = user_fixture()
    assert user.email == "user@test.com"
  end
end

ExUnit.run()
