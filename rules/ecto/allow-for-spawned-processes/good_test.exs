# EXPECTED: passes
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

Ecto.Adapters.SQL.Sandbox.checkout(TestCritic.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(TestCritic.Repo, fn ->
  TestCritic.Repo.query!("""
  CREATE TABLE IF NOT EXISTS sandbox_allow_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT NOT NULL,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
end)
Ecto.Adapters.SQL.Sandbox.checkin(TestCritic.Repo)

ExUnit.start(autorun: false)

defmodule SandboxAllow.Item do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sandbox_allow_items" do
    field :label, :string
    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:label])
    |> validate_required([:label])
  end
end

defmodule AllowForSpawnedProcessesGoodTest do
  use ExUnit.Case, async: false

  alias TestCritic.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias SandboxAllow.Item

  setup do
    :ok = Sandbox.checkout(Repo)
  end

  test "Task with Sandbox.allow can access the DB" do
    parent = self()
    n = System.unique_integer([:positive])

    task = Task.async(fn ->
      # GOOD: allow shares the test's sandbox connection with this task process
      Sandbox.allow(Repo, parent, self())
      Repo.insert!(Item.changeset(%Item{}, %{label: "item-#{n}"}))
    end)

    item = Task.await(task)
    assert item.label == "item-#{n}"

    # Verify the record is visible in the same sandbox
    fetched = Repo.get!(Item, item.id)
    assert fetched.label == "item-#{n}"
  end

  test "multiple tasks each allowed can run concurrently" do
    parent = self()

    tasks = for i <- 1..3 do
      n = System.unique_integer([:positive])
      Task.async(fn ->
        Sandbox.allow(Repo, parent, self())
        Repo.insert!(Item.changeset(%Item{}, %{label: "concurrent-#{n}-#{i}"}))
      end)
    end

    items = Task.await_many(tasks)
    assert length(items) == 3
    assert Enum.all?(items, &(&1.id != nil))
  end
end

ExUnit.run()
