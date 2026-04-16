---
id: ETC-OBAN-002
title: "Use assert_enqueued/1 for enqueue verification"
category: oban
severity: recommendation
summary: >
  When testing that your application code schedules an Oban job, use
  assert_enqueued/1 from Oban.Testing to verify the job was inserted with
  the correct worker, args, and queue. Do not query the oban_jobs table
  directly or inspect return values from new/2.
principles:
  - boundary-testing
applies_when:
  - "Testing that a function inserts a job into the Oban queue"
  - "Verifying a job is scheduled with the correct args and queue after a business action"
  - "Testing scheduling logic (delayed jobs, retries, priority)"
does_not_apply_when:
  - "Testing the logic inside a worker — use perform_job/3 instead (ETC-OBAN-001)"
  - "End-to-end flows where you want the job to actually run — use inline mode (ETC-OBAN-004)"
---

# Use assert_enqueued/1 for enqueue verification

There are two separate concerns in Oban-based workflows:

1. **Was the job scheduled?** — Did your business logic call `Oban.insert/1` with the right args?
2. **Does the job work?** — Does the worker's `perform/1` produce the correct outcome?

`assert_enqueued/1` tests the first concern. It queries the `oban_jobs` table
(in the test database) and asserts that a matching job exists. It accepts a keyword
list of fields to match: `worker`, `args`, `queue`, `priority`, `scheduled_at`, etc.

## Problem

Developers sometimes verify enqueueing by inspecting the `{:ok, job}` return value
from `Oban.insert/1`. This works superficially but couples the test to the return
shape and does not verify the job is actually in the database with the correct queue
and scheduling. `assert_enqueued/1` reads from the actual database, giving you a
higher-confidence assertion.

## Detection

- Tests that pattern-match `{:ok, %Oban.Job{}}` from `Oban.insert/1` to verify args
- Tests that query `Repo.all(Oban.Job)` manually
- Missing `use Oban.Testing, repo: MyApp.Repo` in test files that test scheduling

## Bad

```elixir
defmodule MyApp.OrdersTest do
  use ExUnit.Case, async: true

  test "places order and schedules fulfillment job" do
    {:ok, job} = MyApp.Orders.place_order(%{item: "widget", qty: 3})

    # Fragile: inspects return value, doesn't confirm the row is in the DB
    # with the right queue/priority
    assert job.args["item"] == "widget"
  end
end
```

## Good

```elixir
defmodule MyApp.OrdersTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: MyApp.Repo

  test "places order and schedules fulfillment job" do
    MyApp.Orders.place_order(%{item: "widget", qty: 3})

    assert_enqueued(
      worker: MyApp.FulfillmentWorker,
      args: %{item: "widget", qty: 3},
      queue: :fulfillment
    )
  end

  test "delayed order schedules job in the future" do
    MyApp.Orders.place_order(%{item: "widget", qty: 3, delay_minutes: 30})

    assert_enqueued(
      worker: MyApp.FulfillmentWorker,
      queue: :fulfillment,
      # scheduled_at is within the expected window
    )
  end
end
```

## refute_enqueued

The counterpart `refute_enqueued/1` asserts that no matching job was inserted.
Use it to verify that a failed precondition prevented scheduling:

```elixir
test "out-of-stock order does not schedule fulfillment" do
  MyApp.Orders.place_order(%{item: "discontinued", qty: 1})
  refute_enqueued(worker: MyApp.FulfillmentWorker)
end
```

## Further Reading

- [Oban.Testing — assert_enqueued/1](https://hexdocs.pm/oban/Oban.Testing.html#assert_enqueued/1)
- [Oban testing guide](https://hexdocs.pm/oban/testing.html)
