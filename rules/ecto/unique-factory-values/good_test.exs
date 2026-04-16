# EXPECTED: passes
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

# Create the table inline
Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)

Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS unique_factory_users (
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

defmodule UniqueFactory.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "unique_factory_users" do
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

defmodule UniqueFactory.Fixtures do
  alias TestCritic.Repo
  alias UniqueFactory.User

  # GOOD: unique integer ensures no collision across concurrent tests
  def user_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])
    defaults = %{
      email: "user-#{n}@example.com",
      name: "User #{n}"
    }
    Repo.insert!(User.changeset(%User{}, Map.merge(defaults, attrs)))
  end
end

defmodule UniqueFactoryValuesGoodTest do
  use ExUnit.Case, async: false

  import UniqueFactory.Fixtures
  alias TestCritic.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "factory creates user with unique email each call" do
    user1 = user_fixture()
    user2 = user_fixture()
    refute user1.email == user2.email
  end

  test "factory allows email override" do
    custom_email = "custom-#{System.unique_integer([:positive])}@example.com"
    user = user_fixture(%{email: custom_email})
    assert user.email == custom_email
  end

  test "two concurrent calls to fixture do not collide" do
    # Simulate what would happen if two async tests ran simultaneously
    u1 = user_fixture()
    u2 = user_fixture()
    assert u1.id != u2.id
  end
end

ExUnit.run()
