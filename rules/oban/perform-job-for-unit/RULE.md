---
id: ETC-OBAN-001
title: "Use perform_job/3 for unit testing workers"
category: oban
severity: recommendation
summary: >
  Test Oban worker logic by calling perform_job/3 from Oban.Testing rather than
  constructing Oban.Job structs manually or calling perform/1 directly. perform_job/3
  validates the worker module, converts args to string-keyed maps, and checks JSON
  encodability — giving you the same guarantees Oban itself applies at runtime.
principles:
  - public-interface
  - purity-separation
applies_when:
  - "Testing the business logic inside an Oban worker's perform/1 callback"
  - "Verifying a worker returns :ok, {:ok, value}, :discard, or {:error, reason}"
  - "Testing workers in isolation without a running Oban instance or database"
does_not_apply_when:
  - "Testing that a job was enqueued — use assert_enqueued/1 instead (ETC-OBAN-002)"
  - "End-to-end integration flows — use inline testing mode instead (ETC-OBAN-004)"
---

# Use perform_job/3 for unit testing workers

When unit testing an Oban worker, the goal is to verify that the worker's `perform/1`
callback produces the right result for given arguments. `Oban.Testing.perform_job/3`
is the canonical way to do this: it validates your module is a proper worker, coerces
args to string keys (exactly as Oban does when deserialising from the database), and
checks that the args are JSON-encodable before handing control to your `perform/1`.

Calling `perform/1` directly with an `%Oban.Job{}` you construct manually bypasses
these protections and can hide bugs where your worker assumes atom keys when it will
receive string keys at runtime.

## Problem

Workers receive args as string-keyed maps because JSON serialisation strips atom keys.
If you test with `worker.perform(%Oban.Job{args: %{user_id: 42}})`, your test may pass
while production breaks because your worker pattern-matches on `"user_id"` (a string),
not `:user_id` (an atom). `perform_job/3` does the key conversion for you, matching
what Oban does in production.

## Detection

- `MyWorker.perform(%Oban.Job{args: %{...}})` called directly in a test
- Pattern matching on atom keys inside `perform/1` (often a sign tests are masking the bug)
- `%Oban.Job{}` struct constructed manually in test setup

## Bad

```elixir
defmodule MyApp.EmailWorkerTest do
  use ExUnit.Case, async: true

  alias MyApp.EmailWorker

  test "sends email to user" do
    # Directly calling perform/1 with an atom-keyed map — this is NOT what Oban does.
    # Your worker may pass here but fail in production when it receives string keys.
    job = %Oban.Job{args: %{user_id: 42, template: "welcome"}}
    assert :ok = EmailWorker.perform(job)
  end
end
```

## Good

```elixir
defmodule MyApp.EmailWorkerTest do
  use ExUnit.Case, async: true
  use Oban.Testing, repo: MyApp.Repo

  alias MyApp.EmailWorker

  test "sends email to user" do
    # perform_job/3 converts args to string keys, validates JSON-encodability,
    # and confirms EmailWorker implements Oban.Worker.
    assert :ok = perform_job(EmailWorker, %{user_id: 42, template: "welcome"})
  end

  test "discards job for unknown user" do
    assert {:discard, "user not found"} =
             perform_job(EmailWorker, %{user_id: 0, template: "welcome"})
  end
end
```

## Key Contracts perform_job/3 Enforces

1. **Module is a valid worker** — raises if the module does not implement `Oban.Worker`
2. **Args become string-keyed** — `%{user_id: 42}` becomes `%{"user_id" => 42}`
3. **Args are JSON-encodable** — raises if you pass non-serialisable values (PIDs, references, etc.)
4. **Job fields are settable** — third argument lets you specify `queue`, `priority`, `meta`, etc.

## Setting Job Fields

```elixir
# Test with a specific queue or priority
perform_job(MyWorker, %{id: 1}, queue: :critical, priority: 0)

# Test with scheduled_at in the past (as if a delayed job is now executing)
perform_job(MyWorker, %{id: 1}, scheduled_at: DateTime.add(DateTime.utc_now(), -3600))
```

## Further Reading

- [Oban.Testing docs — perform_job/3](https://hexdocs.pm/oban/Oban.Testing.html#perform_job/3)
- [Oban worker testing guide](https://hexdocs.pm/oban/testing.html)
