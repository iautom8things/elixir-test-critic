---
id: ETC-OTP-005
title: "Test supervision restart with real supervisors"
category: otp
severity: recommendation
summary: >
  Use a real Supervisor started with start_supervised to test crash and restart
  behaviour. Mocking or faking the supervisor means you never verify that your
  child spec, restart strategy, and init callback actually work together.
principles:
  - integration-required
applies_when:
  - "Testing that a supervised process is restarted after it crashes"
  - "Testing that the supervisor applies the correct restart strategy"
  - "Testing that a restarted process initialises with correct state"
---

# Test supervision restart with real supervisors

Supervision trees are OTP infrastructure. Their behaviour — restart strategies,
child specs, init callbacks — must be tested against the real `Supervisor`
module. Faking or stubbing a supervisor tells you nothing about whether your
child specs are correct.

## Problem

Developers sometimes test restart behaviour by directly killing a process and
checking if a new one appears, without involving a supervisor. This misses the
actual contract: does the child spec declare the right restart strategy? Does
the `init/1` callback succeed on restart? Does the supervisor apply the right
`max_restarts` limit?

The right approach is to use `start_supervised` (which uses
`ExUnit.Callbacks`'s supervised runner) or start a real `Supervisor` in the
test, crash the child, and verify the supervisor brings it back.

## Detection

- Tests that call `Process.exit(pid, :kill)` and then `Process.sleep` to wait
  for a replacement, without a supervisor in the test
- Tests that assert a new pid appears after a crash but never started a supervisor
- Missing tests for supervisor restart in modules that use `Supervisor` or
  `DynamicSupervisor`

## Bad

```elixir
test "worker restarts after crash" do
  {:ok, pid} = MyApp.Worker.start_link([])
  # No supervisor — killing it just kills it, nothing restarts it
  Process.exit(pid, :kill)
  Process.sleep(50)
  # This will always fail — there is no supervisor to restart the process
  assert Process.whereis(:my_worker) != nil
end
```

## Good

```elixir
test "worker is restarted by supervisor after crash" do
  {:ok, sup} = start_supervised({
    Supervisor,
    children: [{MyApp.Worker, name: :my_worker}],
    strategy: :one_for_one
  })
  original_pid = GenServer.whereis(:my_worker)
  # Crash the worker
  Process.exit(original_pid, :kill)
  # The supervisor restarts it — wait for a new pid to appear
  assert_eventually(fn -> GenServer.whereis(:my_worker) != nil end)
  new_pid = GenServer.whereis(:my_worker)
  assert new_pid != original_pid
end
```

## When This Applies

- Any module that defines a `child_spec/1` or implements supervisor behaviour
- Tests verifying restart limits (`max_restarts`, `:temporary` vs `:transient`)
- Testing that a process re-initialises correctly after a crash

## When This Does Not Apply

- Pure unit tests of the worker logic — those belong in the pure module
- System tests that start the full application supervision tree
  (the supervisor is implicitly tested)

## Further Reading

- [Elixir docs — Supervisor](https://hexdocs.pm/elixir/Supervisor.html)
- [ExUnit — start_supervised/2](https://hexdocs.pm/ex_unit/ExUnit.Callbacks.html#start_supervised/2)
- [Saša Jurić — "Processes and Supervisors" (Elixir in Action)](https://www.manning.com/books/elixir-in-action)
