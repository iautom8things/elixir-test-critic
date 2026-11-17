---
id: ETC-ECTO-009
title: "Use Sandbox.allow for spawned process DB access"
category: ecto
severity: warning
summary: >
  A process that is not a Task started by the test has no path to the test's
  sandbox connection: a GenServer or Agent, a plain spawn, a worker under
  another supervisor. Call Ecto.Adapters.SQL.Sandbox.allow/3 for it, or it
  raises DBConnection.OwnershipError. Tasks need no allowance.
principles:
  - async-default
applies_when:
  - "A test starts a GenServer, Agent, or other long-lived process that makes DB queries"
  - "The code under test starts a worker under an application supervisor and that worker queries the DB"
  - "A process is started with spawn/1 or spawn_link/1 and queries the DB"
does_not_apply_when:
  - "The process is a Task started from the test process (Task.async, Task.Supervisor): it finds the connection through $callers"
  - "The suite runs in shared sandbox mode ({:shared, pid}), which requires async: false"
related_rules:
  - ETC-ISO-004
---

# Use Sandbox.allow for spawned process DB access

The Ecto SQL Sandbox gives ownership of a database connection to the test
process. When another process uses the Repo, the sandbox looks for an owner in
this order: the process itself, a process that was allowed, then the processes
listed in its `$callers`.

Tasks record their caller in `$callers`. A `Task.async` started from the test
therefore uses the test's connection with no extra call. Other processes do not:

```
** (DBConnection.OwnershipError) cannot find ownership process for #PID<...>
```

Give those processes access with `Sandbox.allow/3`:

```elixir
Sandbox.allow(MyApp.Repo, self(), worker_pid)
```

## Problem

```elixir
test "worker inserts a record" do
  worker = start_supervised!(MyWorker)
  # CRASH: OwnershipError. ExUnit's supervisor started the worker, so it has
  # no caller chain back to this test and was never allowed.
  MyWorker.insert_user(worker, "job@example.com")
end
```

## Detection

- A test starts a GenServer, Agent, or `spawn`ed process that makes Repo calls,
  with no `Sandbox.allow/3` for it and no shared mode
- `DBConnection.OwnershipError` in test output pointing at a PID that is not
  the test process

Do not flag a `Task.async` or `Task.Supervisor` task for a missing allowance.

## Bad

```elixir
test "worker creates record without allow" do
  worker = start_supervised!(MyWorker)
  MyWorker.create(worker, %{field: "value"})  # ← OwnershipError
end
```

## Good

```elixir
test "worker creates record with allow" do
  worker = start_supervised!(MyWorker)
  Sandbox.allow(Repo, self(), worker)
  MyWorker.create(worker, %{field: "value"})
end
```

A Task needs nothing:

```elixir
test "task creates record" do
  task = Task.async(fn -> Repo.insert!(%MySchema{field: "value"}) end)
  assert %MySchema{} = Task.await(task)
end
```

## When This Applies

- A test starts a GenServer, Agent, or `spawn`ed process that performs Repo
  operations during the test
- The code under test starts such a process itself. Allow it once you have its
  PID, or look it up by name

## When This Does Not Apply

- **Tasks started from the test process.** The sandbox finds the connection
  through `$callers`.
- **Shared mode.** With `Sandbox.mode(Repo, {:shared, self()})` every process
  uses the test's connection. That requires `async: false` (see ETC-ISO-004).

## Further Reading

- [Ecto.Adapters.SQL.Sandbox docs — allowances](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#module-allowances)
- [DBConnection.Ownership: callers lookup](https://hexdocs.pm/db_connection/DBConnection.Ownership.html#module-callers-lookup)
- ETC-ISO-004: sandbox ownership strategy
