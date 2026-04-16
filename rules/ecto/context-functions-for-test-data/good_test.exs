# EXPECTED: passes
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS ctx_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    hashed_password TEXT,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
end)
Ecto.Adapters.SQL.Sandbox.checkin(TestCritic.Repo)

ExUnit.start(autorun: false)

defmodule CtxGood.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ctx_users" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "member"
    field :hashed_password, :string
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role])
    |> validate_required([:email, :name])
    |> unique_constraint(:email)
    |> put_change(:hashed_password, "hashed:" <> (attrs[:password] || attrs["password"] || ""))
    |> put_change(:role, attrs[:role] || attrs["role"] || "member")
  end
end

# Context module — the public API
defmodule CtxGood.Accounts do
  alias TestCritic.Repo
  alias CtxGood.User

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end

defmodule ContextFunctionsGoodTest do
  use ExUnit.Case, async: false

  alias CtxGood.Accounts
  alias TestCritic.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  defp unique_user_attrs(overrides \\ %{}) do
    n = System.unique_integer([:positive])
    Map.merge(%{
      email: "user-#{n}@example.com",
      name: "User #{n}",
      password: "secure_pass_#{n}"
    }, overrides)
  end

  test "creates user through context — business rules applied" do
    {:ok, user} = Accounts.create_user(unique_user_attrs())

    # Role default was applied by the context
    assert user.role == "member"
    # Password was hashed by the context
    assert String.starts_with?(user.hashed_password, "hashed:")
  end

  test "context enforces unique email" do
    attrs = unique_user_attrs()
    {:ok, _} = Accounts.create_user(attrs)
    {:error, changeset} = Accounts.create_user(attrs)
    assert changeset.errors[:email] != nil
  end
end

ExUnit.run()
