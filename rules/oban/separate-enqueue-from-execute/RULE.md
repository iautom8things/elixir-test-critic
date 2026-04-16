---
id: ETC-OBAN-003
title: "Separate 'was it enqueued' from 'did it execute'"
category: oban
severity: recommendation
summary: >
  Test enqueueing and job execution as independent concerns in separate test cases.
  One test verifies that the right job was inserted into the queue; a separate test
  verifies that the worker's perform/1 produces the correct outcome when called.
  Conflating them creates slow, brittle tests that are hard to diagnose.
principles:
  - purity-separation
applies_when:
  - "Any business action that both triggers a side effect AND enqueues an Oban job"
  - "Worker tests that also verify the scheduling path"
  - "Integration tests that run a full flow end-to-end"
does_not_apply_when:
  - "True end-to-end smoke tests where confirming the full pipeline is the goal — use inline mode (ETC-OBAN-004)"
---

# Separate "was it enqueued" from "did it execute"

An Oban workflow has two independent concerns that should be tested independently:

**Concern 1 — Scheduling:** Did calling `MyApp.Orders.place_order/1` enqueue a
`FulfillmentWorker` job with the right args?

**Concern 2 — Execution:** When `FulfillmentWorker.perform/1` receives args
`%{"order_id" => 42}`, does it fulfil the order correctly?

When you test both concerns in a single test case, the test fails for two possible
reasons, is slow (because it requires a running job queue), and gives you no signal
about which half broke.

## Problem

A combined test that enqueues and then drains the queue is:

- **Slow** — requires a real Oban queue to process jobs
- **Brittle** — a scheduling change breaks execution tests and vice versa
- **Opaque** — failure messages don't tell you which layer broke
- **Harder to isolate** — worker bugs force you to examine scheduling code

## Detection

- A single test that calls a business function AND then calls `Oban.drain_queue/1`
- Tests that insert a job and call `perform/1` on the result in the same test body
- `use Oban.Testing` with `drain_queue` inside a unit-style worker test

## Bad

```elixir
defmodule MyApp.FulfillmentTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: MyApp.Repo

  test "order triggers fulfillment" do
    # Testing BOTH enqueueing AND execution in one test — bad separation
    MyApp.Orders.place_order(%{order_id: 42})

    # Drain the queue to force execution
    Oban.drain_queue(queue: :fulfillment)

    # Now assert on the side effect of the worker
    assert MyApp.Repo.get_by(Fulfillment, order_id: 42)
  end
end
```

## Good

```elixir
# Test 1: Scheduling concern
defmodule MyApp.OrderSchedulingTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: MyApp.Repo

  test "place_order/1 enqueues a FulfillmentWorker job" do
    MyApp.Orders.place_order(%{order_id: 42})

    assert_enqueued(
      worker: MyApp.FulfillmentWorker,
      args: %{order_id: 42},
      queue: :fulfillment
    )
  end
end

# Test 2: Execution concern — independent unit test
defmodule MyApp.FulfillmentWorkerTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: MyApp.Repo

  test "perform/1 creates a fulfillment record for valid order" do
    assert :ok = perform_job(MyApp.FulfillmentWorker, %{order_id: 42})
    assert MyApp.Repo.get_by(Fulfillment, order_id: 42)
  end

  test "perform/1 discards job for unknown order" do
    assert {:discard, _} = perform_job(MyApp.FulfillmentWorker, %{order_id: 0})
  end
end
```

## Further Reading

- [Oban testing guide — separation of concerns](https://hexdocs.pm/oban/testing.html)
- ETC-OBAN-001 — perform_job/3 for unit testing workers
- ETC-OBAN-002 — assert_enqueued/1 for enqueue verification
