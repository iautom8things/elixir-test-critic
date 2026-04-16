---
id: ETC-ORG-005
title: "Tag tests requiring external resources"
category: organization
severity: recommendation
summary: >
  Use @moduletag :integration or @tag :external_api (or similar) on any test that
  requires a running database, network access, a third-party API, or any other
  resource that may be unavailable in some environments. This lets CI pipelines and
  local workflows exclude slow or environment-dependent tests selectively.
principles:
  - boundary-testing
applies_when:
  - "Tests that require a live database connection (beyond Ecto SQL Sandbox)"
  - "Tests that make real HTTP calls to external services"
  - "Tests that require a running Redis, RabbitMQ, or other external service"
  - "Tests marked as slow that should be excluded from the fast feedback loop"
  - "Tests that require environment secrets (API keys, credentials)"
does_not_apply_when:
  - "Tests using Ecto SQL Sandbox — those are considered unit/integration by convention and need no extra tag"
  - "Tests that use Mox or Bypass to mock external calls — no real external dependency"
  - "Pure unit tests with no external dependencies"
---

# Tag tests requiring external resources

ExUnit's tag system lets you selectively include or exclude tests based on metadata.
Any test that requires an external resource — a live API, a real database, a message
broker — should be tagged so that it can be excluded from fast local runs and CI
unit-test stages.

## Common tags by convention

| Tag | What it marks |
|-----|---------------|
| `:integration` | Tests that require the full application stack (DB, etc.) |
| `:external_api` | Tests that make real HTTP calls to third-party APIs |
| `:slow` | Tests that take more than a second to run |
| `:capture_io` or `:capture_log` | Tests with unusual IO behaviour |

Pick a consistent set for your project and document them in your README or `test/test_helper.exs`.

## Configuration

```elixir
# test/test_helper.exs

# Exclude integration and external tests by default
ExUnit.configure(exclude: [:integration, :external_api])
```

Then in CI:

```bash
# Fast unit tests (default exclusions apply)
mix test

# Full test suite including integration
mix test --include integration

# Only external API tests
mix test --only external_api
```

## Detection

- Tests that start a real database connection without `:integration` tag
- Tests that call `HTTPoison.get/1` or any HTTP client without `:external_api` tag
- Slow tests (> 1s) without `:slow` tag causing CI timeouts
- Tests that require `System.get_env("STRIPE_API_KEY")` without a guard tag

## Bad

```elixir
defmodule MyApp.PaymentTest do
  use ExUnit.Case, async: false
  # No tag! This test hits Stripe's real API and will fail without credentials,
  # or be slow and flaky in environments without network access.

  test "charges a card via Stripe" do
    result = MyApp.Payments.charge("tok_visa", 1000)
    assert {:ok, _charge} = result
  end
end
```

## Good

```elixir
defmodule MyApp.PaymentTest do
  use ExUnit.Case, async: false
  @moduletag :external_api

  # Excluded by default in test_helper.exs — only runs with --include external_api

  test "charges a card via Stripe" do
    result = MyApp.Payments.charge("tok_visa", 1000)
    assert {:ok, _charge} = result
  end
end
```

## Per-test tagging for mixed modules

When only some tests in a module need external resources:

```elixir
defmodule MyApp.PaymentTest do
  use ExUnit.Case, async: true

  # Unit tests — no tag needed
  test "validates card number length" do
    refute MyApp.Payments.valid_card?("1234")
  end

  @tag :external_api
  test "charges a real card via Stripe API" do
    result = MyApp.Payments.charge("tok_visa", 1000)
    assert {:ok, _} = result
  end
end
```

## Further Reading

- [ExUnit tags documentation](https://hexdocs.pm/ex_unit/ExUnit.Case.html#module-tags)
- [mix test --include/--exclude flags](https://hexdocs.pm/mix/Mix.Tasks.Test.html)
