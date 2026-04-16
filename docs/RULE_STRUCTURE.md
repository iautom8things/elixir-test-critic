# Rule Structure Reference

This document is the single source of truth for how rules are structured in this
repo. Both [CONTRIBUTING.md](../CONTRIBUTING.md) and [CLAUDE.md](../CLAUDE.md)
reference this document.

## Directory Layout

Every rule lives in its own directory under `rules/<category>/<slug>/` and
contains exactly three files:

```
rules/<category>/<slug>/
├── RULE.md          # Rule document (frontmatter + prose + examples)
├── good_test.exs    # Runnable script demonstrating the recommended pattern
└── bad_test.exs     # Runnable script demonstrating the anti-pattern
```

Categories live under `rules/<category>/` and contain an `_index.md` file
summarising the category and listing its rules.

## Rule ID Convention

Rule IDs follow the format `ETC-<CATEGORY>-<NNN>`, where:

- `ETC` — Elixir Test Critic
- `<CATEGORY>` — uppercase category name (e.g., `CORE`, `ECTO`, `LIVEVIEW`)
- `<NNN>` — zero-padded three-digit sequence within the category

Examples: `ETC-CORE-001`, `ETC-ECTO-007`, `ETC-LIVEVIEW-003`.

When adding a rule to an existing category, use the next available number.

## RULE.md Frontmatter

Every `RULE.md` begins with YAML frontmatter. See [RULE_TEMPLATE/RULE.md](../RULE_TEMPLATE/RULE.md)
for the canonical template.

### Required fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Rule ID, e.g. `ETC-CORE-001` |
| `title` | string | Human-readable title |
| `category` | string | Category slug (kebab-case), matches directory |
| `severity` | enum | `critical`, `warning`, `recommendation`, or `style` |
| `summary` | string | One-to-two sentence summary |
| `principles` | list | Short names from `rules/00-principles.md` |
| `applies_when` | list | When the rule applies |
| `does_not_apply_when` | list | When the rule does NOT apply |

### Optional fields

| Field | Type | Description |
|-------|------|-------------|
| `tags` | list | Free-form tags for discovery |
| `related_rules` | list | Other rule IDs that inform this one |
| `sources` | list | URLs or references backing the rule |
| `conflicts_with` | list | Rule IDs this one contradicts |
| `status` | enum | Defaults to `active` |

## RULE.md Body

After the frontmatter, prose sections — in order:

1. **Title (H1)** — matches `title` frontmatter
2. **One-line restatement** — the summary in prose form
3. **Problem** — what goes wrong without this rule; include concrete symptoms
4. **Detection** — how a human or LLM reviewer can spot the issue
5. **Bad** — fenced Elixir block matching `bad_test.exs`
6. **Good** — fenced Elixir block matching `good_test.exs`
7. **When This Applies** — expanded `applies_when`
8. **When This Does Not Apply** — expanded `does_not_apply_when`
9. **Further Reading** — links to docs, talks, blog posts

## Example Scripts

Both `good_test.exs` and `bad_test.exs` are standalone scripts runnable with
`elixir <path>` from a bare Elixir install. They must:

- Begin with `# EXPECTED: passes` (every script should exit 0, even the "bad"
  one — the anti-pattern is illustrated in code, not by test failure)
- Start with `Mix.install([...])` declaring any dependencies
- Call `ExUnit.start(autorun: true)`
- Define all needed modules inline unless shared with the sibling script
  and greater than 15 lines — in that case, extract to `support.ex` and use
  `Code.require_file("support.ex", __DIR__)`

`bad_test.exs` also includes a `# BAD PRACTICE:` comment immediately after the
`# EXPECTED:` line describing what is wrong with the approach.

See [RULE_TEMPLATE/good_test.exs](../RULE_TEMPLATE/good_test.exs) and
[RULE_TEMPLATE/bad_test.exs](../RULE_TEMPLATE/bad_test.exs) for canonical templates.

## Category Index (`_index.md`)

Each category directory contains an `_index.md` with:

- Category title (H1)
- **Scope** section — what this category covers and the projects it applies to
- **Rules** section — a markdown listing every rule in the category with its
  ID, slug, title, and severity

Update `_index.md` whenever you add, remove, or change a rule in the category.

## Principles

Every rule references one or more foundational principles by short name in
its `principles` frontmatter. The authoritative list lives in
[rules/00-principles.md](../rules/00-principles.md).

Don't invent new principle short names without discussion — open an issue first.

## Validation and Checks

Two Mix tasks enforce structure:

- `mix validate_rules` — validates frontmatter and directory structure
- `mix check_rules` — executes every `good_test.exs` and `bad_test.exs` and
  asserts each exits 0

Both must pass in CI before a rule can land. Run locally with:

```bash
mix validate_rules
mix check_rules                        # all rules
mix check_rules core                   # one category
mix check_rules core/start-supervised  # one rule
```

After adding a rule, regenerate the TOC:

```bash
mix generate_toc
```

CI asserts the committed TOC matches the generated output.
