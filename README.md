# Elixir Test Critic

[![CI](https://github.com/iautom8things/elixir-test-critic/actions/workflows/validate.yml/badge.svg)](https://github.com/iautom8things/elixir-test-critic/actions/workflows/validate.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Elixir testing rules that actually run.

81 rules across 14 categories, each paired with a runnable `good_test.exs`
and `bad_test.exs` and traced to one of ten foundational principles. CI
re-executes every example on every push across Elixir 1.16–1.19 and OTP
26–28.

It ships as a [Claude Code][cc] skill so an LLM can use the rules to review
or write your tests, and reads as plain Markdown if you'd rather browse them
yourself.

## Install

As a Claude Code plugin:

```
/plugin marketplace add iautom8things/elixir-test-critic
/plugin install elixir-test-critic
```

Claude Code auto-loads the skill whenever you ask it to review, write, or
discuss Elixir tests. You can also invoke it explicitly:

```
/elixir-test-critic review test/my_app/accounts_test.exs
```

Update later with `/plugin marketplace update elixir-test-critic`, remove with
`/plugin uninstall elixir-test-critic`.

Prefer to read the rules yourself? Start at [`toc/RULES_REFERENCE.md`][toc]
for the condensed catalog, or browse [`rules/`][rules] directly.

## What a review looks like

A finding is tied to a specific rule ID, cites the principle it comes from,
and shows the fix — not just the complaint:

```
### [CRITICAL] ETC-CORE-005: Never use Process.sleep for synchronization

File: test/my_app/workers/notifier_test.exs:24

Current:
    Notifier.notify(user)
    Process.sleep(100)
    assert_received {:sent, ^user}

Fix:
    Notifier.notify(user)
    assert_receive {:sent, ^user}, 500

Why: Process.sleep/1 couples the test to wall-clock timing — too short and
it races under CI load, too long and it pads every run for no reason. Wait
on the signal instead (principle: assert-don't-sleep).
```

## What's inside

```
rules/
├── 00-principles.md     # the ten foundational principles
├── _support/            # shared infrastructure for example scripts
├── core/          (10)  # fundamental ExUnit patterns
├── isolation/      (5)  # test isolation
├── errors/         (3)  # error-path testing
├── otp/            (6)  # GenServer / supervisor testing
├── ecto/           (9)  # Ecto / database testing
├── mocking/        (9)  # Mox, Bypass, Req.Test, DI
├── phoenix/        (5)  # controllers, PubSub
├── liveview/       (8)  # LiveView lifecycle
├── oban/           (4)  # Oban workers
├── property/       (4)  # StreamData property tests
├── organization/   (5)  # test suite structure
├── absinthe/       (5)  # Absinthe GraphQL
├── broadway/       (4)  # Broadway pipelines
└── telemetry/      (4)  # Telemetry events
```

Each rule is a directory with a `RULE.md` — YAML frontmatter (`id`,
`category`, `severity`, `principles`, `applies_when`) plus prose and
citations — alongside `good_test.exs` and `bad_test.exs`. Both scripts run
from a bare Elixir install via `Mix.install/1`.
required.

## How the corpus stays honest

**Every rule is executable.** `mix check_rules` runs all 162 example scripts
on every push. A regression against a new Elixir release, a dependency bump,
or an OTP change breaks the build.

**Every rule cites a principle.** Ten foundational principles form the
trunk — purity separation, async default, assert-don't-sleep, and so on.
New rules must reference at least one.

**Severity is strict.** `critical` is reserved for rules that catch real
test bugs: flakiness, false positives, missed regressions. `warning`,
`recommendation`, and `style` absorb everything else.

## Configuring per project

Drop a `.test_critic.yml` next to your `mix.exs` and the skill will read it
before every review:

```yaml
min_severity: warning # critical | warning | recommendation | style
disabled_categories: [property, broadway]
disabled_rules: [ETC-CORE-012]
```

- `min_severity` — ignore findings below this bar. Order is `critical` >
  `warning` > `recommendation` > `style`.
- `disabled_categories` — turn off categories you haven't adopted (property
  testing, Broadway) or don't want opinions on.
- `disabled_rules` — turn off specific rule IDs even when the category
  stays on.

All fields are optional. A missing or malformed file means "use defaults"
(report everything). See [`docs/CONFIG.md`][config] for the full schema and
example profiles.

## The ten principles

1. **Purity Separation** — separate pure logic from side effects
2. **Contracts First** — define behaviours for boundaries
3. **Mock as Noun** — Mox-style mock modules, not monkey-patching
4. **Integration Required** — every mock needs a matching integration test
5. **Async Default** — tests run concurrently unless there's a reason not to
6. **Public Interface** — test the public API, not internals
7. **Thin Processes** — GenServers wrap logic modules; test the logic directly
8. **Honest Data** — realistic, unique test data
9. **Boundary Testing** — test where your code meets external systems
10. **Assert, Don't Sleep** — use `assert_receive`, never `Process.sleep`

Full descriptions in [`rules/00-principles.md`][principles].

## Working on this repo

```bash
mix deps.get
mix validate_rules                       # frontmatter + structure
mix check_rules                          # run every good/bad example
mix check_rules core                     # one category
mix check_rules core/start-supervised    # one rule
mix generate_toc                         # regenerate the catalog
mix test                                 # tests for the mix tasks themselves
```

`make all` runs validate → test → generate → check in sequence.

> **A note on `mix check_rules`**: it executes every example as a subprocess
> (`elixir <script>`), and the scripts use `Mix.install/1` to pull their own
> dependencies. The task exists to prove the examples actually behave as their
> rule claims. Only run it against a rule tree you trust (this repo, or a fork
> you've reviewed). PR reviewers should read every `*.exs` change with the same
> scrutiny as library code.

See [`CONTRIBUTING.md`][contributing] for how to propose a new rule and
[`docs/RULE_STRUCTURE.md`][rule-structure] for the canonical format.

## License

MIT — see [`LICENSE`][license].

[cc]: https://docs.claude.com/en/docs/claude-code
[toc]: toc/RULES_REFERENCE.md
[rules]: rules/
[config]: docs/CONFIG.md
[principles]: rules/00-principles.md
[contributing]: CONTRIBUTING.md
[rule-structure]: docs/RULE_STRUCTURE.md
[license]: LICENSE
