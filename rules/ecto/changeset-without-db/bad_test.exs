# EXPECTED: passes
# BAD PRACTICE: Spins up a full Ecto.Repo (SQLite in-memory) just to test pure
# changeset validations that have no database interaction whatsoever.
# The database is never actually used — the test only checks changeset.valid?.
Mix.install([:ecto_sql, :ecto_sqlite3])

ExUnit.start(autorun: true)

defmodule EctoWithDb.Repo do
  use Ecto.Repo,
    otp_app: :test_critic_bad,
    adapter: Ecto.Adapters.SQLite3
end

Application.put_env(:test_critic_bad, EctoWithDb.Repo,
  database: ":memory:",
  pool_size: 1
)

{:ok, _} = EctoWithDb.Repo.start_link()

defmodule EctoWithDb.User do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :email, :string
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
  end
end

defmodule ChangesetWithoutDbBadTest do
  use ExUnit.Case, async: true

  # BAD: A Repo is started above but never used in any of these tests.
  # All assertions are on changeset.valid? — a pure result.
  # The database connection overhead is wasted.

  test "invalid when email is missing — no DB needed here" do
    cs = EctoWithDb.User.changeset(%EctoWithDb.User{}, %{name: "Alice"})
    refute cs.valid?
    assert cs.errors[:email] != nil
  end

  test "valid changeset — no DB needed here either" do
    cs = EctoWithDb.User.changeset(%EctoWithDb.User{}, %{name: "Alice", email: "alice@example.com"})
    assert cs.valid?
  end
end
