# EXPECTED: passes
# Demonstrates: a process the test did not start as a Task gets its database
# access from Sandbox.allow/3. A Task needs no allowance, because the sandbox
# finds the test's connection through the Task's $callers.
Mix.install([:ecto_sql, :ecto_sqlite3])
Code.require_file("../../_support/db.exs", __DIR__)

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Shampoo.Repo)
Ecto.Adapters.SQL.Sandbox.unboxed_run(Shampoo.Repo, fn ->
  Shampoo.Repo.query!("""
  CREATE TABLE IF NOT EXISTS sandbox_allow_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    label TEXT NOT NULL,
    inserted_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  """)
end)
Ecto.Adapters.SQL.Sandbox.checkin(Shampoo.Repo)

ExUnit.start(autorun: false)

defmodule SandboxAllow.Item do
  use Ecto.Schema

  schema "sandbox_allow_items" do
    field :label, :string
    timestamps()
  end
end

defmodule SandboxAllow.Writer do
  use Agent

  def start_link(_opts), do: Agent.start_link(fn -> nil end)

  def write(pid, label) do
    Agent.get(pid, fn _ -> Shampoo.Repo.insert!(%SandboxAllow.Item{label: label}) end)
  end
end

defmodule AllowForSpawnedProcessesGoodTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias SandboxAllow.{Item, Writer}
  alias Shampoo.Repo

  setup do
    :ok = Sandbox.checkout(Repo)
  end

  test "a supervised worker writes after Sandbox.allow" do
    writer = start_supervised!(Writer)
    # GOOD: the worker was started by ExUnit's supervisor, not by this test
    # process, so it has no path to the test's connection until allowed.
    Sandbox.allow(Repo, self(), writer)

    item = Writer.write(writer, "from-worker")

    assert Repo.get!(Item, item.id).label == "from-worker"
  end

  test "a Task uses the test's connection with no allowance" do
    task = Task.async(fn -> Repo.insert!(%Item{label: "from-task"}) end)

    item = Task.await(task)

    assert Repo.get!(Item, item.id).label == "from-task"
  end
end

ExUnit.run()
