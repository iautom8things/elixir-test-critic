---
id: ETC-ISO-005
title: "on_exit runs in a separate process"
category: isolation
severity: warning
summary: >
  Callbacks registered with `on_exit/1` run in a new process that is not the test
  process. They cannot access test process state, Mox allowances, or Ecto sandbox
  connections set up for the test. Structure cleanup to work within this constraint.
principles:
  - async-default
  - thin-processes
applies_when:
  - "Any test using on_exit to perform cleanup"
  - "on_exit callbacks that need to access database, Mox, or process-specific state"
---

# on_exit runs in a separate process

`on_exit/1` registers a callback that ExUnit runs after the test completes. This
callback runs in a **new process** spawned by ExUnit, not in the test process. This
has important implications: the callback cannot access process dictionary values,
Ecto sandbox connections checked out by the test process, or Mox allowances granted
to the test process.

## Problem

**Ecto sandbox in on_exit**: if you check out an Ecto sandbox connection in the test
process and then try to use `Repo.*` in `on_exit`, it will either raise
`DBConnection.OwnershipError` or use a different connection — potentially one that
doesn't see the test's uncommitted data.

**Mox in on_exit**: `Mox.verify_on_exit!/1` works because it uses a mechanism that
explicitly handles the process boundary. But manually setting up Mox expectations in
`on_exit` (e.g., to stub a cleanup call) fails because the allowance was granted to
the test process, not the on_exit process.

**Process dictionary**: `Process.put/2` in the test process is not visible in `on_exit`
because it's a different process.

The correct approach is to do cleanup that is independent of the test process's specific
connections — use `start_supervised` (which handles cleanup automatically) or pass
explicit references (pids, connection refs) into closures.

## Detection

- `Repo.*` calls inside `on_exit` callbacks
- `Process.get` inside `on_exit`
- `Mox` expectation setup inside `on_exit`
- `on_exit` that uses variables from the test process that might be connection handles

## Bad

```elixir
test "creates and deletes a record" do
  {:ok, record} = Repo.insert(%MySchema{name: "temp"})
  on_exit(fn ->
    # Wrong: this on_exit process doesn't own the sandbox connection
    Repo.delete(record)   # raises DBConnection.OwnershipError
  end)
  assert record.id > 0
end
```

## Good

```elixir
# Option 1: Don't clean up — let the sandbox rollback handle it
test "creates a record" do
  # The entire test runs in a transaction that rolls back — no cleanup needed
  {:ok, record} = Repo.insert(%MySchema{name: "temp"})
  assert record.id > 0
end

# Option 2: Allow the on_exit process access to the sandbox
test "creates and explicitly verifies deletion" do
  owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: false)
  on_exit(fn ->
    # Grant on_exit process access before it needs to use the repo
    Ecto.Adapters.SQL.Sandbox.allow(Repo, owner, self())
    Repo.delete_all(MySchema)
    Ecto.Adapters.SQL.Sandbox.stop_owner(owner)
  end)
  {:ok, record} = Repo.insert(%MySchema{name: "temp"})
  assert record.id > 0
end
```

## When This Applies

- Any `on_exit` that needs to use `Repo.*`, Mox, or process-specific state
- Cleanup that involves database operations or supervised processes

## When This Does Not Apply

- `on_exit` for non-process cleanup (deleting files, reverting `Application.put_env`,
  stopping agents) — these work fine because they don't depend on process-specific state
- `Mox.verify_on_exit!` — it uses an internal mechanism that handles the process boundary

## Further Reading

- [ExUnit.Callbacks — on_exit/2](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#on_exit/2)
- [Ecto SQL Sandbox — allowing processes](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#allow/3)
