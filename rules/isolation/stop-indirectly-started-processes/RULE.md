---
id: ETC-ISO-006
title: "Stop processes the code under test starts under app supervisors"
category: isolation
severity: critical
summary: >
  When the code under test starts a child under an application-level supervisor
  (a DynamicSupervisor, Horde, a Task.Supervisor), `start_supervised` never sees
  it and it outlives the test. Stop those children from the case template, in
  sync tests, before the sandbox owner stops.
principles:
  - async-default
  - thin-processes
related_rules:
  - ETC-CORE-006
  - ETC-ISO-004
  - ETC-ISO-005
  - ETC-MOCK-010
applies_when:
  - "A LiveView mount, controller or context function starts a process under a supervisor the application owns"
  - "A test exercises code that calls DynamicSupervisor.start_child, Horde.DynamicSupervisor.start_child or Task.Supervisor.start_child on an app-level name"
  - "Sync tests share a sandbox (`shared: true`) or use global-mode mocks"
does_not_apply_when:
  - "The test starts the process itself; use start_supervised (ETC-CORE-006)"
  - "The process is linked to the test process, so it exits with the test"
  - "The child is a boot-time singleton that every test relies on"
tags: [leak, flaky, horde, dynamic-supervisor, liveview]
---

# Stop processes the code under test starts under app supervisors

`start_supervised` cleans up only what the test starts. A child that the code
under test starts under an application-level supervisor is not linked to the
test, so it keeps running after the test ends. Stop it from the case template.

## Problem

A LiveView that starts a session process on mount, a context function that
spawns a worker under `MyApp.DynamicSupervisor`, or a request that puts work on
`MyApp.TaskSupervisor` all create processes that belong to the application, not
the test. When the test ends, ExUnit stops the LiveView. The application's child
keeps going.

The leftovers fail other tests, so the failure never points at the test that
leaked:

- They call into global-mode mocks (`set_mimic_global`, `Mox.set_mox_global`)
  and answer for whichever test is running. A stub that sends the test a message
  then delivers a stranger's data. See ETC-MOCK-010.
- They keep querying through a shared sandbox whose owner is gone, which logs
  `DBConnection.ConnectionError ... owner exited`, or they write through the
  next test's sandbox.
- If their own child dies, they restart it, so they stay active rather than
  idle.

One Phoenix suite with an agent session per chat page left 176 such sessions
alive after the tests that started them, all of them until the end of the
suite. 135 were running while the test that failed was running.

`stop_session` in `on_exit` does not fix this reliably. Each test has to
remember it, and in that suite the modules that did call it still leaked from
the tests that did not.

## Detection

- A test mounts a LiveView or calls a context function whose implementation
  calls `start_child` on an app-named supervisor, and nothing in the test or
  case template stops that child.
- `Horde.DynamicSupervisor`, `DynamicSupervisor` or `Task.Supervisor` names in
  `application.ex` that the code under test starts children under.
- Log noise across the suite: `owner exited`, `StaleEntryError`, or "restarting"
  warnings from processes no current test started.
- A count of `which_children` that grows across sync tests.

## Bad

```elixir
defmodule MyAppWeb.ChatLiveTest do
  use MyAppWeb.ConnCase, async: false

  test "mount opens a session", %{conn: conn} do
    # Mount calls MyApp.Sessions.open/1, which starts a child under
    # MyApp.SessionSupervisor. Nothing stops it when the test ends.
    {:ok, _view, _html} = live(conn, ~p"/chat")
  end
end
```

## Good

```elixir
# test/support/data_case.ex, called by ConnCase as well
def setup_sandbox(tags) do
  sync? = not tags[:async]
  if sync?, do: MyApp.TestProcesses.sweep!()
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: sync?)
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  # Registered after the owner's on_exit, so it runs first (on_exit is LIFO):
  # leftovers stop while the sandbox they hold is still open.
  if sync?, do: on_exit(&MyApp.TestProcesses.sweep!/0)
end

# test/support/test_processes.ex
def sweep! do
  for {_, pid, _, _} <- DynamicSupervisor.which_children(MyApp.SessionSupervisor),
      is_pid(pid),
      do: DynamicSupervisor.terminate_child(MyApp.SessionSupervisor, pid)

  for pid <- Task.Supervisor.children(MyApp.TaskSupervisor),
      do: Task.Supervisor.terminate_child(MyApp.TaskSupervisor, pid)

  :ok
end
```

Stopping every child is exact only in sync tests. ExUnit runs all async modules
first, then sync modules one at a time, so during a sync test every child of
these supervisors came from this test or an earlier one. In an async test the
same sweep would kill other tests' processes. There, inject a test-owned
supervisor or have the API return the pid so the test can stop it.

Check two things before you sweep everything:

- **The supervisor holds nothing at boot.** Look at `which_children` before the
  first test. If it holds a singleton, snapshot the children at setup and stop
  only the new ones.
- **Use `terminate_child`, not `Process.exit(pid, :kill)`.** A `:transient` or
  `:permanent` child that is killed gets restarted. Stop the parents first (for
  example, sessions before their tasks), because a live parent may restart a
  child you just stopped.

## When This Applies

- Any test that drives code which starts processes under supervisors defined in
  the application tree.
- Suites that rely on sync tests running one at a time for isolation, through a
  shared sandbox or global mocks. A leaked process breaks that assumption.

## When This Does Not Apply

- **Processes the test starts itself**: use `start_supervised` (ETC-CORE-006).
- **Linked processes**: a process linked to the test process exits with it.
- **Boot-time singletons**: never sweep a supervisor whose children every test
  needs. Snapshot and diff instead, or leave that supervisor out.

## Further Reading

- [ExUnit.Callbacks — on_exit/2](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#on_exit/2)
- [DynamicSupervisor.terminate_child/2](https://hexdocs.pm/elixir/DynamicSupervisor.html#terminate_child/2)
- [Ecto.Adapters.SQL.Sandbox — shared mode](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html#module-shared-mode)
