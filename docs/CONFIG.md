# Project Configuration

Consumers of the `elixir-test-critic` skill can opt out of specific rules,
categories, or severity tiers by adding a `.test_critic.yml` file to the root
of their project (next to `mix.exs`). The skill reads this file before every
review and filters findings accordingly.

## Schema

```yaml
# .test_critic.yml

# Suppress findings below this severity.
# One of: critical | warning | recommendation | style
# Default: no threshold (all severities reported).
min_severity: warning

# Skip every rule in these categories.
# Valid categories: core, isolation, errors, organization, otp, ecto,
# mocking, phoenix, liveview, oban, property, absinthe, broadway, telemetry
disabled_categories:
  - property
  - broadway

# Skip specific rule IDs even when their category is enabled.
disabled_rules:
  - ETC-CORE-012
  - ETC-PHX-004
```

All three fields are optional. An empty or missing file means "use defaults"
(report every rule at every severity).

## Severity Order

From most to least severe:

1. `critical` — catches real test bugs (flakiness, false positives, missed regressions)
2. `warning` — practices that meaningfully degrade test quality
3. `recommendation` — improvements worth considering
4. `style` — preference-level nits

Setting `min_severity: warning` reports `critical` and `warning` only.

## Example Profiles

### Strict — report everything

Either omit the file entirely or:

```yaml
min_severity: style
```

### Pragmatic — focus on real bugs

```yaml
min_severity: warning
```

### Phoenix-only project that skips property tests

```yaml
min_severity: warning
disabled_categories:
  - property
  - broadway
  - absinthe
```

### Team that disagrees with one specific rule

```yaml
disabled_rules:
  - ETC-CORE-012
```

## Where to Put It

`.test_critic.yml` lives at the **project root**, alongside `mix.exs`. Commit
it so the whole team and CI share the same policy.

## Discovery

Rule IDs and category names come from `toc/RULES_REFERENCE.md` in this repo.
Browse there to pick what to disable.
