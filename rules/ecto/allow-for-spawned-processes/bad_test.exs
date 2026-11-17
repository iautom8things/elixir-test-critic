# EXPECTED: passes
# BAD PRACTICE: a worker the test did not start as a Task touches the database
# with no Sandbox.allow/3. It cannot find the test's connection and raises
# DBConnection.OwnershipError. The script passes because the test asserts on
# that error, to show the failure a real suite would hit.
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

:ok = Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS bad_allow_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT NOT NULL,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
end)
Ecto.Adapters.SQL.Sandbox.checkin(TestCritic.Repo)

ExUnit.start(autorun: false)

defmodule SandboxAllowBad.Item do
  use Ecto.Schema

  schema "bad_allow_items" do
    field :label, :string
    timestamps()
  end
end

defmodule AllowForSpawnedProcessesBadTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias SandboxAllowBad.Item
  alias TestCritic.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
  end

  test "a spawned process without Sandbox.allow cannot reach the database" do
    test_pid = self()

    # BAD: spawn/1 records no caller, and nothing allowed this process.
    spawn(fn ->
      result =
        try do
          Repo.insert!(%Item{label: "never-written"})
        rescue
          error in DBConnection.OwnershipError -> {:ownership_error, error}
        end

      send(test_pid, result)
    end)

    assert_receive {:ownership_error, %DBConnection.OwnershipError{}}, 5_000
  end
end

ExUnit.run()
