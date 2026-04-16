# EXPECTED: passes
# BAD PRACTICE: In PostgreSQL, a test for a DEFERRABLE INITIALLY DEFERRED constraint
# that checks for an error at the INSERT statement (not at transaction commit) will
# silently miss the violation — the INSERT succeeds and the test's {:error, _} branch
# is never hit.
#
# SQLite constraints are always immediate, so this script passes.
# The structural problem only manifests in Postgres with deferred constraints.
# The bad test below shows the wrong assertion pattern: checking for an error
# at INSERT when using deferred constraints — in Postgres this would produce a
# false-positive (the insert succeeds, assert fails or is structured wrong).
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS bad_ordered_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    position INTEGER NOT NULL,
    label TEXT NOT NULL,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
  TestCritic.Repo.query!(
    "CREATE UNIQUE INDEX IF NOT EXISTS bad_ordered_items_position ON bad_ordered_items (position)"
  )
end)
Ecto.Adapters.SQL.Sandbox.checkin(TestCritic.Repo)

ExUnit.start(autorun: false)

defmodule DeferredConstraintBad.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bad_ordered_items" do
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

defmodule DeferredConstraintGotchaBadTest do
  use ExUnit.Case, async: false

  alias TestCritic.Repo
  alias DeferredConstraintBad.Item

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # BAD PATTERN (for Postgres deferred constraints):
  # In Postgres, if :position had a DEFERRABLE INITIALLY DEFERRED unique constraint,
  # the second insert below would SUCCEED (returning {:ok, item}) because the
  # constraint check is deferred to commit. The test would then fail on the
  # assert {:error, _} = ... line — or worse, a developer might flip the assertion
  # to assert {:ok, _} and lose coverage entirely.
  #
  # In SQLite (used here), this works correctly because SQLite is always immediate.
  # The problem only bites in production Postgres schemas.
  test "demonstrates the deferred constraint gotcha pattern" do
    n = System.unique_integer([:positive])
    position = rem(n, 10_000) + 1

    {:ok, _} = Repo.insert(Item.changeset(%Item{}, %{position: position, label: "first"}))

    # In SQLite this correctly errors. In Postgres with a DEFERRED constraint,
    # this would return {:ok, item} — causing the test to fail or be written incorrectly.
    # The fix: use SET CONSTRAINTS ALL IMMEDIATE before this insert (Postgres only).
    result = Repo.insert(Item.changeset(%Item{}, %{position: position, label: "second"}))

    # Documenting what you'd see in Postgres with a deferred constraint:
    # result would be {:ok, _} — the bad case that SET CONSTRAINTS ALL IMMEDIATE prevents
    case result do
      {:error, changeset} ->
        # SQLite path — immediate constraint, correct behaviour
        assert changeset.errors[:position] != nil
      {:ok, _item} ->
        # This is what happens in Postgres with DEFERRED — the insert succeeds
        # and you don't catch the violation until commit (or never, if you don't check)
        flunk("Constraint was not enforced at insert time — use SET CONSTRAINTS ALL IMMEDIATE in Postgres")
    end
  end
end

ExUnit.run()
