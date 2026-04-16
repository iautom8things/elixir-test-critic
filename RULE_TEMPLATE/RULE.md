---
id: ETC-CAT-NNN
title: "Rule title here"
category: category-name
severity: warning
summary: >
  One to two sentence summary of what the rule recommends
  and why it matters.
principles:
  - principle-short-name
applies_when:
  - "description of when this rule applies"
does_not_apply_when:
  - "description of when this rule does NOT apply"
# Optional fields:
# tags: [tag1, tag2]
# related_rules: [ETC-CAT-NNN]
# sources: ["URL or reference"]
# conflicts_with: [ETC-CAT-NNN]
# status: active
---

# Rule title here

One to two sentence summary restated in prose form.

## Problem

Describe the anti-pattern or mistake this rule catches. What goes wrong when
developers don't follow this guidance? Include concrete symptoms: flaky tests,
false positives, process leaks, etc.

## Detection

How can a reviewer (human or LLM) spot this problem?

- Look for X in the test code
- Check if Y is missing
- Notice when Z is used instead of W

## Bad

```elixir
# Anti-pattern code here — matches bad_test.exs
```

## Good

```elixir
# Recommended pattern — matches good_test.exs
```

## When This Applies

- Bullet list matching `applies_when` frontmatter, with more detail

## When This Does Not Apply

- Bullet list matching `does_not_apply_when` frontmatter, with more detail

## Further Reading

- Links to Elixir docs, blog posts, or HexDocs
