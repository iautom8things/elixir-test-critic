# Oban Rules

Rules for testing Oban background job workers and scheduling logic.

Oban is a robust background job processor for Elixir backed by PostgreSQL. Testing
Oban workflows requires thinking about two distinct concerns: **scheduling** (was the
right job inserted into the right queue with the right args?) and **execution** (does
the worker's `perform/1` produce the correct outcome?). Conflating these produces
slow, brittle tests.

## Rules in this category

| ID | Rule | Severity |
|----|------|----------|
| [ETC-OBAN-001](perform-job-for-unit/) | Use perform_job/3 for unit testing workers | recommendation |
| [ETC-OBAN-002](assert-enqueued-for-integration/) | Use assert_enqueued/1 for enqueue verification | recommendation |
| [ETC-OBAN-003](separate-enqueue-from-execute/) | Separate "was it enqueued" from "did it execute" | recommendation |
| [ETC-OBAN-004](inline-mode-for-integration/) | Use inline testing mode for end-to-end tests | recommendation |

## Key concepts

**`perform_job/3`** (from `Oban.Testing`) is the unit testing helper. It:
- Validates the module implements `Oban.Worker`
- Converts args to string-keyed maps (matching Oban's JSON deserialisation)
- Checks that args are JSON-encodable

**`assert_enqueued/1`** verifies scheduling. It queries the `oban_jobs` table to
confirm a job was inserted with the expected worker, args, and queue.

**Testing modes** control whether inserted jobs execute:
- `:manual` (default in tests) — jobs are inserted, never run
- `:inline` — jobs execute synchronously on insert (ideal for integration tests)
- `:disabled` — Oban is not started at all

## Setup

```elixir
# In test files that use Oban helpers
use Oban.Testing, repo: MyApp.Repo
```

```elixir
# config/test.exs — for inline mode
config :my_app, Oban,
  testing: :inline,
  repo: MyApp.Repo,
  queues: false,
  plugins: false
```
