# EXPECTED: passes
# BAD PRACTICE: The factory uses a hardcoded email "user@test.com".
# In this script each test calls the factory once inside its own rolled-back
# sandbox transaction, so both succeed. A test that called the factory twice would
# fail on the second insert, and concurrent tests sharing the value would wait on
# each other's row lock. The script shows the shape, not a collision.
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

Ecto.Adapters.SQL.Sandbox.checkout(Shampoo.Repo)

Ecto.Adapters.SQL.Sandbox.unboxed_run(Shampoo.Repo, fn ->
  Shampoo.Repo.query!("""
  CREATE TABLE IF NOT EXISTS bad_factory_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    name TEXT,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
end)

Ecto.Adapters.SQL.Sandbox.checkin(Shampoo.Repo)

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
  alias Shampoo.Repo
  alias BadFactory.User

  # BAD: hardcoded email. A second call in the same test hits the unique index.
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
  alias Shampoo.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "one call per test works, because the sandbox rolls each test back" do
    user = user_fixture()
    assert user.email == "user@test.com"
  end

  test "a second call in the same test fails on the unique index" do
    user_fixture()

    # The hardcoded default makes the factory unusable twice in one test.
    assert_raise Ecto.InvalidChangesetError, ~r/has already been taken/, fn ->
      user_fixture()
    end
  end
end

ExUnit.run()
