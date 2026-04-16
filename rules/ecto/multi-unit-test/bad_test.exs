# EXPECTED: passes
# BAD PRACTICE: Tests the Multi pipeline structure by running it against a DB
# rather than using Ecto.Multi.to_list/1 to inspect it without infrastructure.
# The test verifies result keys, which is a proxy for operation names —
# but requires a real database connection and sandbox setup.
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS multi_bad_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
end)
Ecto.Adapters.SQL.Sandbox.checkin(TestCritic.Repo)

ExUnit.start(autorun: false)

defmodule MultiBad.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "multi_bad_users" do
    field :email, :string
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
  end
end

defmodule MultiBad.Accounts do
  alias MultiBad.User

  def register_user_multi(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:user, User.changeset(%User{}, attrs))
    |> Ecto.Multi.run(:audit_log, fn _repo, _changes ->
      {:ok, %{action: "created"}}
    end)
  end
end

defmodule MultiUnitTestBadTest do
  use ExUnit.Case, async: false

  alias MultiBad.Accounts
  alias TestCritic.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # BAD: runs the full transaction to check structure — database not needed for this
  test "register_user_multi produces user and audit_log results" do
    n = System.unique_integer([:positive])
    {:ok, result} = Repo.transaction(Accounts.register_user_multi(%{email: "u#{n}@e.com"}))

    # These assertions are about structure (which operations ran),
    # not about the data content — no DB needed for structural tests
    assert Map.has_key?(result, :user)
    assert Map.has_key?(result, :audit_log)
  end
end

ExUnit.run()
