# Elixir Test Critic

A testing knowledge base for Elixir where the rules can't rot into lies and
can't quietly turn into one person's preferences.

## Why it exists

Most "testing best practices" docs are blog posts. They go stale, the examples
stop working against current dependencies, and nobody notices because nobody's
running them. This repo is shaped to avoid that.

Every rule is executable. Every rule has to trace back to a principle. The whole
corpus is validated by CI on every push. The rules get treated like a library —
if they regress, the build breaks.

## How it's built

**Rules are data.** Each rule lives in its own directory with a `RULE.md` (YAML
frontmatter: `id`, `category`, `severity`, `principles`, `applies_when`) plus
two scripts: `good_test.exs` showing the recommended pattern and `bad_test.exs`
showing the anti-pattern. Both run from a bare Elixir install via
`Mix.install/1`.

**CI runs all of them.** `mix check_rules` executes all 162 example scripts on
every push, across a matrix of Elixir 1.16–1.18 and OTP 26–27. A regression
against a new Elixir version, a dependency bump, or an OTP change breaks the
build. There's nowhere for rot to hide.

**Nothing ships without a principle.** Ten foundational principles form the
trunk — purity separation, async default, assert-don't-sleep, and so on. Every
new rule cites at least one. That's how the corpus stays out of the "I just
like it this way" swamp.

**Severity is strict.** `critical` is reserved for rules that catch real test
bugs: flakiness, false positives, missed regressions. `warning`,
`recommendation`, and `style` absorb everything else. Filter by severity and
the result is trustworthy.

**One artifact, two audiences.** The same rules feed a Claude Code skill for
LLM-driven test review and generation, and serve as docs a human can browse on
GitHub. No second copy to keep in sync.

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

## Configuring the critic per project

Drop a `.test_critic.yml` next to your `mix.exs` and the critic will read it
before every review:

```yaml
min_severity: warning           # critical | warning | recommendation | style
disabled_categories: [property, broadway]
disabled_rules: [ETC-CORE-012]
```

- `min_severity` — ignore findings below this bar. Order is `critical` >
  `warning` > `recommendation` > `style`.
- `disabled_categories` — turn off entire categories (e.g. you haven't adopted
  property-based testing yet, or you don't use Broadway).
- `disabled_rules` — turn off specific rule IDs even if the category stays on.

All three fields are optional. Missing or malformed file means "use defaults"
(report every rule at every severity). See `docs/CONFIG.md` for the full schema
and example profiles.

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
