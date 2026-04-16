---
id: ETC-ISO-001
title: "Never use Application.put_env in async tests"
category: isolation
severity: critical
summary: >
  Do not call `Application.put_env/3` or `Application.delete_env/2` in tests
  marked `async: true`. Application environment is a global VM-wide store; mutations
  from one async test are immediately visible to all other concurrent tests.
principles:
  - async-default
applies_when:
  - "Any async test that needs to vary application configuration per test"
  - "Any test that calls Application.put_env, Application.delete_env, or Application.put_all_env"
does_not_apply_when:
  - "Tests explicitly use async: false and document why (e.g., # async: false — modifies Application env)"
related_rules:
  - ETC-MOCK-007
  - ETC-TELE-003
---

# Never use Application.put_env in async tests

`Application.put_env/3` writes to a global ETS table shared across all processes
in the VM. When an async test calls `Application.put_env(:my_app, :key, value)`,
every other concurrent test immediately sees that value, potentially changing their
behavior in unpredictable ways.

## Problem

The failure mode is subtle and maddening: tests pass in isolation, pass when run
individually with `mix test test/my_test.exs`, but fail intermittently when the full
suite runs with `mix test`. The failures depend on which tests happen to run
concurrently, which changes with each run.

A typical scenario:
1. Test A (async) sets `Application.put_env(:app, :feature_flag, true)`
2. Test B (async, concurrent) reads `Application.get_env(:app, :feature_flag)` and
   gets `true` instead of the expected `nil`
3. Test B fails with a confusing assertion error about feature flag behavior

The root cause is that application environment is global mutable state — the opposite
of what async tests require.

## Detection

- `Application.put_env` in any test module with `async: true`
- `Application.delete_env` in any async test
- `on_exit(fn -> Application.put_env(...) end)` in async tests (the cleanup may
  be too late — other tests have already run)

## Bad

```elixir
defmodule MyApp.FeatureTest do
  use ExUnit.Case, async: true   # async: true + Application.put_env = race condition

  test "feature is enabled when flag is set" do
    Application.put_env(:my_app, :feature_enabled, true)
    assert MyApp.feature_enabled?()
  end
end
```

## Good

```elixir
# Option 1: Make the function accept configuration as a parameter
defmodule MyApp.FeatureTest do
  use ExUnit.Case, async: true

  test "feature is enabled when flag is set" do
    assert MyApp.feature_enabled?(feature_enabled: true)
  end
end

# Option 2: Use async: false with a comment explaining why
defmodule MyApp.FeatureTest do
  use ExUnit.Case, async: false   # async: false — modifies Application env

  setup do
    original = Application.get_env(:my_app, :feature_enabled)
    on_exit(fn -> Application.put_env(:my_app, :feature_enabled, original) end)
    :ok
  end

  test "feature is enabled when flag is set" do
    Application.put_env(:my_app, :feature_enabled, true)
    assert MyApp.feature_enabled?()
  end
end
```

## When This Applies

- All tests with `async: true` that involve application configuration
- Any use of `Application.put_env`, `Application.delete_env`, or `Application.put_all_env`
  in test code

## When This Does Not Apply

- Tests explicitly marked `async: false` that document the reason for the sequential mode
- `test_helper.exs` setup that runs before any tests — safe because no concurrent
  tests are running yet
- `setup_all` that sets configuration once for the whole module — acceptable if the
  module is sequential (`async: false`) and restores the original value in `on_exit`

## Further Reading

- [Application module docs](https://hexdocs.pm/elixir/Application.html)
- [Saša Jurić — "Testing GenServers with global state"](https://medium.com/very-big-things/towards-maintainable-elixir-testing-part-1-of-4-4e0571440bf0)
