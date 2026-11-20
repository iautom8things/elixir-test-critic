---
id: ETC-ORG-006
title: "Keep build-time configuration deterministic"
category: organization
severity: warning
summary: >
  Keep build-time config stable so Mix can reuse compiled code. Generate run-specific values at runtime.
principles:
  - purity-separation
applies_when:
  - "A run-specific value is generated in build-time config."
does_not_apply_when:
  - "The value is computed in config/runtime.exs or when the application needs it."
enforced_by: credo:Shampoo.Check.NondeterministicConfig
---

# Keep build-time configuration deterministic

Keep build-time config stable so Mix can reuse compiled code. Generate run-specific values at runtime.

## Problem

Clock reads, random values and unique references can change each time Mix evaluates config. When the configuration changes, Mix can invalidate cached compilation work, so a test partition may compile code it could otherwise reuse.

## Detection

Look in config/*.exs for values derived from the clock, random generators, or unique values. Follow variables that feed into a config entry.

## Bad

```elixir
import Config
config :widget, generation: System.unique_integer([:positive, :monotonic])
```

## Good

```elixir
import Config
config :widget, generation: 1
```

## When This Applies

- A run-specific value is generated in build-time config.

## When This Does Not Apply

- The value is computed in config/runtime.exs or when the application needs it.

## Further Reading

- [Mix release configuration](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-application-configuration)
