# Working on Elixir Test Critic

This file is the source of truth for AI tools working on this repo. It is
symlinked as `AGENTS.md` for tools that follow that convention (Codex, etc.).

## What This Repo Is

A curated knowledge base of idiomatic Elixir/ExUnit testing rules. Each rule is
a directory containing a `RULE.md` (frontmatter + prose + examples) and two
runnable example scripts (`good_test.exs`, `bad_test.exs`).

The rules are consumed in two ways:

1. **As a skill** — via `SKILL.md` at the repo root. An AI assistant loads the
   skill and reads rules on demand from `${CLAUDE_SKILL_DIR}/rules/`.
2. **As documentation** — humans browse `rules/` directly on GitHub.

## Project Layout

```
.
├── SKILL.md                   # Claude Code / Agent Skills entry point
├── CLAUDE.md / AGENTS.md      # This file (AI contributor context)
├── CONTRIBUTING.md            # Human contribution guidelines
├── LICENSE                    # MIT
├── docs/
│   └── RULE_STRUCTURE.md      # Canonical rule structure spec
├── RULE_TEMPLATE/             # Starting point for new rules
├── rules/
│   ├── 00-principles.md       # Ten foundational principles
│   ├── _support/              # Shared infrastructure for example scripts
│   └── <category>/
│       ├── _index.md          # Category summary + rule listing
│       └── <slug>/
│           ├── RULE.md
│           ├── good_test.exs
│           └── bad_test.exs
├── toc/
│   └── RULES_REFERENCE.md     # Auto-generated condensed catalog
├── templates/
│   └── toc_template.md.eex    # EEx template for RULES_REFERENCE.md
├── lib/mix/tasks/             # validate_rules, check_rules, generate_toc
└── test/                      # Tests for the mix tasks and support modules
```

## Rule Format

See [`docs/RULE_STRUCTURE.md`](docs/RULE_STRUCTURE.md) for the authoritative
specification: frontmatter fields, directory conventions, example script
requirements, and category index format. Do not duplicate that content here.

## Commands You'll Run

```bash
mix deps.get               # Fetch dependencies
mix validate_rules         # Validate frontmatter + structure
mix check_rules            # Run every good_test.exs and bad_test.exs
mix check_rules <category> # One category
mix check_rules <cat>/<slug>  # One rule
mix generate_toc           # Regenerate toc/RULES_REFERENCE.md
mix test                   # Project tests (mix task internals)
```

`make all` runs validate, test, generate, and check in sequence.

## When Adding a Rule

1. Confirm the idea isn't already covered — check `toc/RULES_REFERENCE.md`.
2. Pick the correct category under `rules/`. If none fit, discuss in an issue
   before creating a new category.
3. Copy `RULE_TEMPLATE/` to `rules/<category>/<slug>/`.
4. Fill out the frontmatter per `docs/RULE_STRUCTURE.md`.
5. Assign the next free `ETC-<CATEGORY>-NNN` ID in that category.
6. Write honest, self-contained `good_test.exs` and `bad_test.exs` — both must
   exit 0.
7. Add the rule to `rules/<category>/_index.md`.
8. Run `mix validate_rules && mix check_rules <cat>/<slug>` locally.
9. Run `mix generate_toc` and commit the regenerated TOC.

## When Modifying a Rule

- Update frontmatter, prose, and examples together — they must stay consistent.
- If you change the ID or slug, update cross-references in `related_rules`,
  `conflicts_with`, and the category `_index.md`.
- Regenerate the TOC with `mix generate_toc` and commit.

## When Modifying Mix Tasks or Support Code

- Source lives in `lib/test_critic/` and `lib/mix/tasks/`.
- Tests live in `test/`.
- Run `mix test` after changes.
- If behavior of `validate_rules` or `check_rules` changes, verify CI still
  passes — `.github/workflows/validate.yml` runs the full suite across
  Elixir 1.16-1.19 and OTP 26-28.

## Style Guardrails

- **Principles over preferences.** Every rule must trace to one or more
  principles in `rules/00-principles.md`. Don't add rules based on personal
  style.
- **Severity discipline.** Reserve `critical` for rules that catch real test
  bugs (flakiness, false positives, missed regressions). Use `warning` for
  practices that degrade quality, `recommendation` and `style` for everything
  else.
- **Examples are runnable.** Every script uses `Mix.install/1` for dependencies
  and must work from a bare Elixir install. No external setup.
- **Cite sources.** If a rule quotes or leans on a talk, blog post, or doc,
  put it in `Further Reading`.

## What Not to Do

- Don't hand-edit `toc/RULES_REFERENCE.md`. It is generated. CI will fail if
  the committed file drifts from `mix generate_toc` output.
- Don't invent new principle short names without discussion. The ten
  principles in `rules/00-principles.md` are deliberate.
- Don't introduce dependencies to the project beyond what's needed for the
  mix tasks themselves.
- Don't commit anything in `tmp/` — it's produced by the `use-tmp-dir` rule's
  example script and is gitignored.
