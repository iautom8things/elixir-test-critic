---
id: ETC-OBAN-004
title: "Use inline testing mode for end-to-end tests"
category: oban
severity: recommendation
summary: >
  Configure Oban with testing: :inline in your test environment for end-to-end
  integration tests. Inline mode executes jobs synchronously in the calling process
  immediately after insert, without needing a queue drainer or background workers.
  This enables true integration smoke tests without flaky timing.
principles:
  - integration-required
applies_when:
  - "End-to-end integration tests that need jobs to execute as part of the flow"
  - "Smoke tests that verify a full business workflow from trigger to completion"
  - "Tests that need to assert on side effects produced by the worker after a business action"
does_not_apply_when:
  - "Unit tests for individual workers — use perform_job/3 instead (ETC-OBAN-001)"
  - "Tests that verify scheduling only — use assert_enqueued/1 instead (ETC-OBAN-002)"
  - "Tests where you explicitly want to test async behaviour or retries"
  - "Testing worker logic in isolation without queue infrastructure — use perform_job (ETC-OBAN-003)"
---

# Use inline testing mode for end-to-end tests

Oban provides three testing modes for different needs:

| Mode | Behaviour | Best for |
|------|-----------|----------|
| `:manual` (default) | Jobs are inserted but never executed | Unit tests, assert_enqueued |
| `:inline` | Jobs execute synchronously on insert | Integration / smoke tests |
| `:disabled` | Oban is not started | Tests that must not touch Oban at all |

Inline mode is the right choice when you need to write an integration test that
exercises a complete workflow from business action to final side effect, and you
want it to be deterministic (no `Process.sleep/1`, no `drain_queue/1` calls).

## Configuration

```elixir
# config/test.exs
config :my_app, Oban,
  testing: :inline,
  repo: MyApp.Repo,
  queues: false,
  plugins: false
```

With `:inline`, calling `Oban.insert/1` (or `Oban.insert!/1`) causes `perform/1`
to run synchronously before returning. The calling process owns the execution.

## Problem

Without inline mode, tests must either:
- Use `Oban.drain_queue/1` — which processes all pending jobs but requires
  knowing which queue to drain and adds coupling
- Use `Process.sleep/1` — fragile, timing-dependent, CI-unfriendly

Both approaches make tests harder to read and prone to intermittent failure.

## Detection

- `Process.sleep` in test files that also reference Oban workers
- `Oban.drain_queue(queue: :some_queue)` in integration tests
- Long, non-obvious setup blocks trying to synchronise with background job execution

## Bad

```elixir
# test/integration/order_flow_test.exs
defmodule MyApp.OrderFlowTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: MyApp.Repo

  test "order placement triggers fulfillment" do
    MyApp.Orders.place_order(%{order_id: 42})

    # Fragile: either sleep and hope, or drain manually
    Oban.drain_queue(queue: :fulfillment)

    assert MyApp.Repo.get_by(Fulfillment, order_id: 42)
  end
end
```

## Good

```elixir
# config/test.exs — set once
config :my_app, Oban, testing: :inline, repo: MyApp.Repo, queues: false, plugins: false

# test/integration/order_flow_test.exs
defmodule MyApp.OrderFlowTest do
  use ExUnit.Case, async: false

  test "order placement triggers fulfillment synchronously" do
    # With inline mode, place_order enqueues the job AND runs it immediately
    MyApp.Orders.place_order(%{order_id: 42})

    # No drain, no sleep — the job already ran
    assert MyApp.Repo.get_by(Fulfillment, order_id: 42)
  end
end
```

## Using inline mode for specific tests only

If you cannot set inline mode globally, configure it per-test via `Oban.Testing`:

```elixir
setup tags do
  Oban.Testing.with_testing_mode(:inline, fn ->
    # code that inserts jobs will run them inline within this block
  end)
end
```

## Further Reading

- [Oban.Testing — testing modes](https://hexdocs.pm/oban/Oban.Testing.html)
- [Oban configuration guide](https://hexdocs.pm/oban/configuration.html)
