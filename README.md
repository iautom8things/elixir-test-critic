# Elixir Test Critic

A curated knowledge base of idiomatic Elixir testing rules, grounded in the
Elixir community's testing philosophy.

## What This Is

A collection of self-contained, opinionated testing rules organized by category.
Each rule includes:

- **RULE.md** — The rule document with YAML frontmatter, problem description, detection hints, and code examples
- **good_test.exs** — A runnable script demonstrating the recommended pattern (must exit 0)
- **bad_test.exs** — A runnable script demonstrating the anti-pattern

Every example script is fully self-contained via `Mix.install/1` — run it with
`elixir rules/core/start-supervised/good_test.exs` from a bare Elixir install.

## Two Consumption Patterns

**Criticism mode:** Fan out sub-agents per category, each evaluating rules against
test code. Output: pass/fail per rule with suggested fixes.

**Generation mode:** Load the auto-generated `toc/RULES_REFERENCE.md` as context
when writing tests. The condensed reference helps produce tests that follow all rules.

## Structure

```
rules/
├── 00-principles.md          # 10 foundational testing principles
├── _support/                  # Shared infrastructure (SQLite repo, etc.)
├── core/                      # 10 rules — fundamental ExUnit patterns
├── isolation/                 # 5 rules — test isolation
├── errors/                    # 3 rules — error path testing
├── otp/                       # 6 rules — GenServer/OTP testing
├── ecto/                      # 9 rules — Ecto/database testing
├── mocking/                   # 9 rules — Mox, Bypass, DI
├── phoenix/                   # 5 rules — controllers, PubSub
├── liveview/                  # 8 rules — LiveView lifecycle
├── oban/                      # 4 rules — Oban workers
├── property/                  # 4 rules — StreamData
└── organization/              # 5 rules — test suite structure
```

## Install as a Claude Code Plugin

Add the marketplace, then install:

```
/plugin marketplace add iautom8things/elixir-test-critic
/plugin install elixir-test-critic
```

Once installed, Claude Code will auto-load the skill whenever you ask it to
review, write, or discuss Elixir tests. You can also invoke it explicitly:

```
/elixir-test-critic review test/my_app/accounts_test.exs
```

To update later:

```
/plugin marketplace update elixir-test-critic
```

To uninstall:

```
/plugin uninstall elixir-test-critic
```

## Setup

```bash
mix deps.get
```

## Usage

### Validate all rules (frontmatter + structure)

```bash
mix validate_rules
```

### Run all rule example scripts

```bash
mix check_rules                        # All rules
mix check_rules core                   # One category
mix check_rules core/start-supervised  # One rule
```

> **Heads up**: `mix check_rules` executes every `good_test.exs` and
> `bad_test.exs` as a subprocess (`elixir <script>`). That is the point —
> the task exists to verify the examples actually behave as the rule
> documents claim. The scripts use `Mix.install/1` to pull their own
> dependencies. Only run `mix check_rules` against a rule tree you trust
> (this repo, or a fork you've reviewed). PR reviewers should read every
> `*.exs` change with the same scrutiny as library code.

### Generate the TOC reference

```bash
mix generate_toc
```

### Run project tests

```bash
mix test
```

## Foundational Principles

1. **Purity Separation** — Separate pure logic from side effects
2. **Contracts First** — Define behaviours for boundaries
3. **Mock as Noun** — Mox-style mock modules, not monkey-patching
4. **Integration Required** — Every mock needs a corresponding integration test
5. **Async Default** — Tests run concurrently unless there's a reason not to
6. **Public Interface** — Test the public API, not internals
7. **Thin Processes** — GenServers wrap logic modules, test the logic directly
8. **Honest Data** — Realistic, unique test data
9. **Boundary Testing** — Test where your code meets external systems
10. **Assert, Don't Sleep** — Use assert_receive, not Process.sleep

See `rules/00-principles.md` for the full descriptions.
