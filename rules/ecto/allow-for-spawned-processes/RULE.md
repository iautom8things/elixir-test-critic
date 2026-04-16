---
id: ETC-ECTO-009
title: "Use Sandbox.allow for spawned process DB access"
category: ecto
severity: warning
summary: >
  When a test spawns a process (Task, GenServer, Agent) that needs to access the
  database, you must call Ecto.Adapters.SQL.Sandbox.allow/3 to share the test's
  sandbox connection with the spawned process. Without it the spawned process has
  no database access and will raise a DBConnection.OwnershipError.
principles:
  - async-default
applies_when:
  - "A test spawns a Task, GenServer, or any process that makes DB queries"
  - "Using Task.async/1 or Task.start/1 in test context"
  - "Starting a supervised process that performs Repo operations during the test"
  - "Testing code paths that spawn background workers touching the database"
related_rules:
  - ETC-ISO-004
---

# Use Sandbox.allow for spawned process DB access

The Ecto SQL Sandbox grants ownership of a database connection to the test process.
Any other process that tries to use the Repo will fail with:

```
** (DBConnection.OwnershipError) cannot find ownership process for #PID<...>
```

This happens because the sandbox does not automatically share ownership with child
processes. You must explicitly call `Sandbox.allow/3` to delegate access:

```elixir
Sandbox.allow(MyApp.Repo, self(), child_pid)
```

## Problem

```elixir
test "background job inserts record" do
  :ok = Sandbox.checkout(Repo)
  task = Task.async(fn ->
    # CRASH: OwnershipError — no Sandbox.allow was called
    Repo.insert!(%User{email: "job@example.com"})
  end)
  Task.await(task)
end
```

## Detection

- A test spawns a process (Task, Process.spawn, GenServer.start, start_supervised)
  and that process makes Repo calls
- `DBConnection.OwnershipError` errors in test output pointing to spawned PIDs

## Bad

```elixir
test "worker creates record without allow" do
  :ok = Sandbox.checkout(Repo)
  task = Task.async(fn ->
    Repo.insert!(%MySchema{field: "value"})  # ← OwnershipError
  end)
  Task.await(task)
end
```

## Good

```elixir
test "worker creates record with allow" do
  :ok = Sandbox.checkout(Repo)
  parent = self()
  task = Task.async(fn ->
    Sandbox.allow(Repo, parent, self())
    Repo.insert!(%MySchema{field: "value"})
  end)
  Task.await(task)
end
```

Or, if starting before spawning:

```elixir
test "pre-allowed worker" do
  :ok = Sandbox.checkout(Repo)
  {:ok, pid} = MyWorker.start_link()
  Sandbox.allow(Repo, self(), pid)
  MyWorker.do_work(pid)
end
```

## When This Applies

- Any test that spawns a process (Task, GenServer, Agent, Process.spawn) that
  performs Repo operations during the test lifecycle

## Further Reading

- [Ecto.Adapters.SQL.Sandbox docs — allowances](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#module-allowances)
- ISO-004 — sandbox ownership strategy
