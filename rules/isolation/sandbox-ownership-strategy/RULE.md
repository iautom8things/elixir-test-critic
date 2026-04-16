---
id: ETC-ISO-004
title: "Choose sandbox mode and ownership based on process needs"
category: isolation
severity: warning
summary: >
  Select the Ecto SQL Sandbox mode — automatic, manual, or shared — based on
  whether your test spawns processes that need database access. Use
  `Sandbox.start_owner!/2` for manual mode and `Sandbox.allow/3` to grant
  access to spawned processes.
principles:
  - async-default
applies_when:
  - "Any test using Ecto with SQL Sandbox"
  - "Tests that spawn GenServers, Tasks, or other processes that perform database operations"
  - "Tests that need to verify concurrent database access patterns"
related_rules:
  - ETC-ECTO-009
---

# Choose sandbox mode and ownership based on process needs

The Ecto SQL Sandbox provides three modes for controlling database connection ownership
in tests. Choosing the wrong mode leads to either `DBConnection.OwnershipError` crashes
or missing isolation that allows test data to leak between tests.

## The Three Modes

### Automatic mode (`:auto`)

The default mode for most test setups. Each test process automatically receives a
checked-out database connection. Spawned processes that are direct children of the
test process can inherit the connection automatically.

```elixir
# In test_helper.exs:
Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :auto)

# In test:
use ExUnit.Case, async: true
# No setup needed — connection is automatic
```

### Manual mode (`:manual`)

Required when you need explicit control over which processes have database access,
or when using async tests with processes that don't inherit from the test process.

```elixir
# In test_helper.exs:
Ecto.Adapters.SQL.Sandbox.mode(MyApp.Repo, :manual)

# In test setup:
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(MyApp.Repo)
end
```

### Shared ownership with `allow/3`

When a spawned process (Task, GenServer started via `start_supervised`) needs database
access, you must explicitly grant it using `Sandbox.allow/3`. This is required in
manual mode and sometimes in auto mode when the spawned process is not a direct child.

```elixir
setup do
  owner = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: false)
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)
  %{sandbox_owner: owner}
end

test "worker has db access", %{sandbox_owner: owner} do
  {:ok, worker_pid} = start_supervised(MyWorker)
  Ecto.Adapters.SQL.Sandbox.allow(MyApp.Repo, owner, worker_pid)
  # Now worker_pid can access the database within this test's transaction
end
```

## Problem

The most common mistake is starting a GenServer or Task that queries the database
without granting it sandbox access. The spawned process gets `DBConnection.OwnershipError`
because it doesn't own a connection and hasn't been explicitly allowed.

The second most common mistake is using `:shared` mode (which grants ALL processes
access to one connection) in async tests — this eliminates isolation and causes
tests to see each other's uncommitted data.

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

- Tests that only use the Repo directly from the test process — automatic checkout
  handles this without any manual setup
- Tests using an in-memory store (not Ecto) — no sandbox needed

## Further Reading

- [Ecto.Adapters.SQL.Sandbox docs](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html)
- [Ecto.Adapters.SQL.Sandbox.start_owner!/2](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#start_owner!/2)
- [José Valim — "Ecto 3.0 and SQL Sandbox"](https://dashbit.co/blog/ecto-3-0)
