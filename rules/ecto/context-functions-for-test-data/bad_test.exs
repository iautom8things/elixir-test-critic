# EXPECTED: passes
# BAD PRACTICE: Uses Repo.insert directly instead of going through a context function.
# Business rules (password hashing, default role assignment) are bypassed.
# The resulting test data can never exist in a real running application.
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS ctx_bad_users (
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

defmodule CtxBad.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ctx_bad_users" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "member"
    field :hashed_password, :string
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :hashed_password])
    |> validate_required([:email, :name])
    |> unique_constraint(:email)
  end
end

defmodule ContextFunctionsBadTest do
  use ExUnit.Case, async: false

  alias TestCritic.Repo
  alias CtxBad.User

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "creates user directly via Repo — skips context business rules" do
    n = System.unique_integer([:positive])
    # BAD: raw Repo.insert bypasses password hashing, role defaulting, etc.
    # hashed_password will be nil — impossible state in production
    {:ok, user} = Repo.insert(%User{
      email: "user-#{n}@example.com",
      name: "User #{n}",
      role: "member",
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    })

    # The test "passes" but user.hashed_password is nil — a state that
    # Accounts.create_user/1 would never allow
    assert user.id != nil
    assert is_nil(user.hashed_password)  # this shows the bypass — would be non-nil via context
  end
end

ExUnit.run()
