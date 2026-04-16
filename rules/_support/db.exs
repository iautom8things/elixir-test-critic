# rules/_support/db.exs
# Provides TestCritic.Repo backed by SQLite in-memory mode.
# Usage: Code.require_file("../../_support/db.exs", __DIR__)

defmodule TestCritic.Repo do
  use Ecto.Repo,
    otp_app: :test_critic,
    adapter: Ecto.Adapters.SQLite3
end

Application.put_env(:test_critic, TestCritic.Repo,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1
)

{:ok, _} = TestCritic.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(TestCritic.Repo, :manual)
