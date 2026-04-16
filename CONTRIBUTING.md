# Contributing

Thanks for your interest in improving Elixir Test Critic. This project is a
curated knowledge base of idiomatic Elixir testing rules, grounded in the
Elixir community's testing philosophy. Contributions that extend, correct,
or clarify that body of knowledge are welcome.

## What Belongs Here

- **New rules** — patterns or anti-patterns observed in real-world Elixir test
  code, especially when they trace back to a foundational principle
- **Corrections** — fixes to rule prose, frontmatter, or example scripts
- **Clarifications** — improving `applies_when` / `does_not_apply_when`,
  sharpening detection hints, or adding `Further Reading` links
- **New categories** — when a class of testing concerns doesn't fit existing
  ones (open an issue first to discuss)

## What Doesn't Belong Here

- **Non-Elixir testing advice** — this project is scoped to Elixir/ExUnit
- **Personal style preferences** — rules must trace to a principle and be
  defensible with real-world symptoms
- **Advocacy for specific frameworks** — be accurate about tradeoffs, don't
  evangelize
- **Duplicates of existing rules** — search the TOC first; if your idea
  overlaps, propose an edit rather than a new rule

## How to Add a Rule

1. **Read the principles** — every rule must reference one or more of the
   ten principles in [`rules/00-principles.md`](rules/00-principles.md).
2. **Pick a category** — existing categories live under `rules/`. Open an
   issue if you believe a new category is warranted.
3. **Copy the template** — use [`RULE_TEMPLATE/`](RULE_TEMPLATE/) as your
   starting point.
4. **Follow the rule structure spec** — see [`docs/RULE_STRUCTURE.md`](docs/RULE_STRUCTURE.md)
   for the canonical format (frontmatter fields, directory layout, example
   script requirements).
5. **Write runnable examples** — both `good_test.exs` and `bad_test.exs` must
   exit 0. The anti-pattern is illustrated by code, not test failure.
6. **Update the category index** — add your rule to `rules/<category>/_index.md`.
7. **Regenerate the TOC** — run `mix generate_toc` and commit the result.

## Quality Gates

Every pull request runs CI against Elixir 1.16-1.18 and OTP 26-27. The
following must pass:

- `mix validate_rules` — frontmatter and directory structure are valid
- `mix test` — project tests pass
- `mix generate_toc` — the committed TOC matches generated output (`git diff --exit-code toc/`)
- `mix check_rules` — every rule's example scripts exit 0

Run locally before opening a PR:

```bash
mix deps.get
mix validate_rules
mix test
mix generate_toc
mix check_rules
```

Or with the provided Makefile:

```bash
make setup
make all
```

## Pull Request Checklist

- [ ] Rule follows the structure in [`docs/RULE_STRUCTURE.md`](docs/RULE_STRUCTURE.md)
- [ ] Rule ID is unique and uses the next available sequence in its category
- [ ] Frontmatter includes every required field
- [ ] `principles` references at least one short name from `rules/00-principles.md`
- [ ] Both `good_test.exs` and `bad_test.exs` exit 0
- [ ] `bad_test.exs` has a `# BAD PRACTICE:` comment describing the anti-pattern
- [ ] Category `_index.md` lists the new rule
- [ ] `mix validate_rules`, `mix check_rules`, `mix test` all pass locally
- [ ] TOC is regenerated with `mix generate_toc`

## Style Notes

- Keep rule prose direct and specific — concrete symptoms beat abstract language
- Cite upstream sources (Elixir docs, HexDocs, talks, blog posts) in
  `Further Reading` whenever a claim depends on them
- Prefer `recommendation` / `warning` over `critical` unless the rule catches
  real test bugs (not style preferences)

## Reporting Issues

Open a GitHub issue for:

- Rules you disagree with — include your reasoning and any counter-example
- Unclear or misleading detection hints
- Example scripts that don't run on your version of Elixir/OTP
- Suggestions for new categories

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
