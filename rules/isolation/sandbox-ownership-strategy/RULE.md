---
id: ETC-ISO-004
title: "Choose sandbox mode and ownership based on process needs"
category: isolation
severity: warning
summary: >
  Run the suite in manual sandbox mode, where each test owns a connection whose
  work is rolled back. Grant other processes access with `Sandbox.allow/3`, or
  fall back to shared mode with `async: false`. Automatic mode does not isolate
  tests.
principles:
  - async-default
applies_when:
  - "Any test using Ecto with SQL Sandbox"
  - "Tests that spawn GenServers, Tasks, or other processes that perform database operations"
  - "Tests that need to verify concurrent database access patterns"
related_rules:
  - ETC-ECTO-009
  - ETC-ISO-006
---

# Choose sandbox mode and ownership based on process needs

The Ecto SQL Sandbox has three modes for deciding which process may use a
database connection. The wrong one gives either `DBConnection.OwnershipError`
crashes or no isolation at all.

## The Three Modes

### Automatic mode (`:auto`)

The mode the pool starts in. Any process that uses the Repo checks out a
connection implicitly, as with an ordinary pool. Nothing wraps that work in a
sandbox transaction, so writes are committed and later tests see them. It
exists so migrations and seeds can run before the suite starts. It does not
isolate tests.

### Manual mode (`:manual`)

The mode a test suite should run in. Set it once in `test_helper.exs`. Each
test then checks out its own connection, and the sandbox wraps everything the
test does in a transaction that is rolled back when the owner exits. This is
what makes `async: true` safe with a database.

```elixir
# In test_helper.exs:
Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)

# In test setup (Phoenix's DataCase does this for you):
setup do
  owner = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: false)
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)
  %{sandbox_owner: owner}
end
```

Only the owner can use the connection. Tasks started from the test find it
through `$callers`. Any other process needs `Sandbox.allow/3` (see ETC-ECTO-009):

```elixir
test "worker has db access", %{sandbox_owner: owner} do
  {:ok, worker_pid} = start_supervised(MyWorker)
  Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, owner, worker_pid)
  # Now worker_pid can access the database within this test's transaction
end
```

### Shared mode (`{:shared, pid}`)

Every process uses the one connection owned by `pid`, with no allowances. Use it
when you cannot reach the processes that need access. Two tests cannot share one
connection, so it requires `async: false`. `start_owner!(repo, shared: true)`
sets it.

## Problem

The most common mistake is starting a GenServer or Task that queries the database
without granting it sandbox access. The spawned process gets `DBConnection.OwnershipError`
because it doesn't own a connection and hasn't been explicitly allowed.

The second most common mistake is using shared mode (which gives every process
the same connection) in async tests. Concurrent tests then run inside one
transaction and see each other's uncommitted data.

## Detection

- `DBConnection.OwnershipError` in test output when processes spawn and query the database
- `Sandbox.allow` missing after `start_supervised` for a database-touching process
- `:shared` mode used in async tests (breaks isolation)
- `Ecto.Adapters.SQL.Sandbox.checkout` without a corresponding `checkin` or `on_exit` cleanup

## Bad

```elixir
test "worker processes jobs" do
  {:ok, worker} = start_supervised(MyWorker)
  # Worker tries to query the database — raises DBConnection.OwnershipError
  # because no Sandbox.allow was called
  MyWorker.process_next_job(worker)
  assert_receive :job_done, 1000
end
```

## Good

```elixir
setup do
  owner = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: false)
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)
  %{owner: owner}
end

test "worker processes jobs", %{owner: owner} do
  {:ok, worker} = start_supervised(MyWorker)
  Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, owner, worker)
  MyWorker.process_next_job(worker)
  assert_receive :job_done, 1000
end
```

## When This Applies

- Tests using Ecto SQL Sandbox that spawn supervised processes accessing the database
- Any test where `DBConnection.OwnershipError` appears
- Integration tests that verify async database operations

## When This Does Not Apply

- Tests that only use the Repo directly from the test process. The checkout in
  the case template's setup is all they need
- Tests using an in-memory store (not Ecto) — no sandbox needed

## Further Reading

- [Ecto.Adapters.SQL.Sandbox docs](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [Ecto.Adapters.SQL.Sandbox.start_owner!/2](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#start_owner!/2)
