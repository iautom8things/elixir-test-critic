# EXPECTED: passes
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

# Create the table and unique index inline (SQLite)
Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS constraint_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    name TEXT,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
  TestCritic.Repo.query!(
    "CREATE UNIQUE INDEX IF NOT EXISTS constraint_users_email_index ON constraint_users (email)"
  )
end)
Ecto.Adapters.SQL.Sandbox.checkin(TestCritic.Repo)

ExUnit.start(autorun: false)

defmodule ConstraintNeedsDb.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "constraint_users" do
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

defmodule ConstraintNeedsDbGoodTest do
  use ExUnit.Case, async: false

  alias TestCritic.Repo
  alias ConstraintNeedsDb.User

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "accepts a valid unique email on first insert" do
    email = "user-#{System.unique_integer([:positive])}@example.com"
    changeset = User.changeset(%User{}, %{email: email, name: "Alice"})
    assert {:ok, user} = Repo.insert(changeset)
    assert user.email == email
  end

  test "rejects duplicate email — constraint fires on second insert" do
    email = "dup-#{System.unique_integer([:positive])}@example.com"

    # First insert succeeds
    {:ok, _} = Repo.insert(User.changeset(%User{}, %{email: email, name: "Alice"}))

    # Second insert with same email hits the unique index
    {:error, changeset} = Repo.insert(User.changeset(%User{}, %{email: email, name: "Bob"}))

    # The constraint error is now in changeset.errors
    assert changeset.errors[:email] != nil
  end
end

ExUnit.run()
