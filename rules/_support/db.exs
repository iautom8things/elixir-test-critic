# rules/_support/db.exs
# Provides Shampoo.Repo backed by SQLite in-memory mode.
# Usage: Code.require_file("../../_support/db.exs", __DIR__)

defmodule Shampoo.Repo do
  use Ecto.Repo,
    otp_app: :shampoo,
    adapter: Ecto.Adapters.SQLite3
end

Application.put_env(:shampoo, Shampoo.Repo,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1
)

{:ok, _} = Shampoo.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Shampoo.Repo, :manual)
