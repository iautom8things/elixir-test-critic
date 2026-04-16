# EXPECTED: passes
# BAD PRACTICE: Demonstrates a Task accessing the DB without Sandbox.allow.
# In a real Ecto.Adapters.SQL.Sandbox :manual setup, this would raise:
#   ** (DBConnection.OwnershipError) cannot find ownership process for #PID<...>
#
# This script uses {:shared, self()} sandbox mode so the Task can query without
# Sandbox.allow — the point is to show the structural problem. In a real test suite
# with :manual mode (the correct default), the Task would crash without Sandbox.allow.
Mix.install([{:ecto_sql, "~> 3.0"}, {:ecto_sqlite3, ">= 0.0.0"}])
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
  import Ecto.Changeset

  schema "bad_allow_items" do
    field :label, :string
    timestamps()
  end

  def changeset(item, attrs) do
    item |> cast(attrs, [:label]) |> validate_required([:label])
  end
end

defmodule AllowForSpawnedProcessesBadTest do
  use ExUnit.Case, async: false

  alias TestCritic.Repo
  alias SandboxAllowBad.Item

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    # BAD: switching to shared mode so Tasks can access the DB without explicit allow.
    # This masks the problem. In a real :manual sandbox setup, omitting Sandbox.allow
    # would cause DBConnection.OwnershipError in any spawned process.
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  # BAD: In a real :manual sandbox setup (correct for test suites), this Task
  # would raise DBConnection.OwnershipError because Sandbox.allow was never called.
  # Using {:shared, self()} mode here to demonstrate the structural pattern without
  # crashing — but the structural anti-pattern is missing the Sandbox.allow call.
  test "Task without Sandbox.allow — would fail in :manual sandbox mode" do
    n = System.unique_integer([:positive])

    task = Task.async(fn ->
      # BAD: no Sandbox.allow(Repo, parent, self()) before this call
      # In :manual sandbox mode this raises DBConnection.OwnershipError
      Repo.insert!(Item.changeset(%Item{}, %{label: "item-#{n}"}))
    end)

    # This only works because we switched to {:shared, self()} mode.
    # In a real test suite with Sandbox in :manual mode, Task.await would
    # surface the OwnershipError crash.
    item = Task.await(task)
    assert item.label == "item-#{n}"
  end
end

ExUnit.run()
