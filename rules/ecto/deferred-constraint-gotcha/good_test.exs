# EXPECTED: passes
# NOTE: SQLite does not support deferred constraints — constraints are always immediate.
# This test demonstrates correct immediate constraint testing (equivalent to what you
# get in Postgres after SET CONSTRAINTS ALL IMMEDIATE).
# For real deferred constraint testing in Postgres, see RULE.md.
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS ordered_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    position INTEGER NOT NULL,
    label TEXT NOT NULL,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
  TestCritic.Repo.query!("CREATE UNIQUE INDEX IF NOT EXISTS ordered_items_position ON ordered_items (position)")
end)
Ecto.Adapters.SQL.Sandbox.checkin(TestCritic.Repo)

ExUnit.start(autorun: false)

defmodule DeferredConstraint.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ordered_items" do
    field :position, :integer
    field :label, :string
    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:position, :label])
    |> validate_required([:position, :label])
    |> unique_constraint(:position)
  end
end

defmodule DeferredConstraintGoodTest do
  use ExUnit.Case, async: false

  alias TestCritic.Repo
  alias DeferredConstraint.Item

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # GOOD: SQLite checks the constraint immediately — this is what you want in tests.
  # In Postgres with a deferred unique constraint, use SET CONSTRAINTS ALL IMMEDIATE
  # before the second insert to force immediate evaluation.
  test "unique position constraint fires immediately on duplicate insert" do
    n = System.unique_integer([:positive])
    position = rem(n, 10_000) + 1

    {:ok, _} = Repo.insert(Item.changeset(%Item{}, %{position: position, label: "first"}))

    # Good: we test the insert and expect the constraint error
    {:error, changeset} = Repo.insert(Item.changeset(%Item{}, %{position: position, label: "second"}))
    assert changeset.errors[:position] != nil
  end

  test "different positions do not violate constraint" do
    n = System.unique_integer([:positive])
    base = rem(n, 10_000) * 10

    {:ok, item1} = Repo.insert(Item.changeset(%Item{}, %{position: base + 1, label: "first"}))
    {:ok, item2} = Repo.insert(Item.changeset(%Item{}, %{position: base + 2, label: "second"}))

    assert item1.position != item2.position
  end
end

ExUnit.run()
