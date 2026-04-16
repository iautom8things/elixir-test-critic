---
id: ETC-ORG-001
title: "Mirror lib/ structure in test/"
category: organization
severity: style
summary: >
  Test files should correspond 1:1 to source files. If a module lives at
  lib/my_app/accounts/user.ex, its tests should be at
  test/my_app/accounts/user_test.exs. This makes tests discoverable, keeps
  the relationship between code and tests explicit, and prevents orphaned tests.
principles:
  - public-interface
applies_when:
  - "Any test file that tests a specific module"
  - "New modules being added to lib/"
  - "Reorganising existing modules and their tests"
does_not_apply_when:
  - "Integration test files that span multiple modules (place in test/integration/)"
  - "Support modules and shared fixtures (place in test/support/)"
  - "End-to-end tests driven by user actions (place in test/features/ or test/e2e/)"
---

# Mirror lib/ structure in test/

When a test file corresponds to a single module, it should live at the same path
under `test/` as the source file lives under `lib/`, with `_test.exs` appended.

```
lib/my_app/accounts/user.ex         →  test/my_app/accounts/user_test.exs
lib/my_app/accounts/user/policy.ex  →  test/my_app/accounts/user/policy_test.exs
lib/my_app/payments/invoice.ex      →  test/my_app/payments/invoice_test.exs
```

This one-to-one correspondence makes the codebase navigable by anyone familiar
with either `lib/` or `test/`. When you open a source file, you know immediately
where the tests are. When a module is deleted, the orphaned test file becomes
obvious.

## Problem

When test files don't mirror the source structure:

- Finding tests for a specific module requires a search rather than navigation
- Orphaned test files are hard to identify (the source was deleted but the test remains)
- New team members have no convention to follow
- CI diff views don't show source and test files adjacently

## Detection

- Test files in `test/` root that test modules deep in `lib/`
- Test files named after the test scenario rather than the module under test
  (e.g., `test/when_user_registers_test.exs` for `lib/my_app/accounts.ex`)
- Multiple modules tested in a single test file (split them)

## Bad

```
lib/
  my_app/
    accounts/
      user.ex
      session.ex
    payments/
      invoice.ex

test/
  user_test.exs          # Should be test/my_app/accounts/user_test.exs
  auth_tests.exs         # Tests session.ex — name doesn't match module
  test_payments.exs      # Doesn't follow _test.exs convention
```

## Good

```
lib/
  my_app/
    accounts/
      user.ex
      session.ex
    payments/
      invoice.ex

test/
  my_app/
    accounts/
      user_test.exs
      session_test.exs
    payments/
      invoice_test.exs
  support/
    fixtures.ex          # Shared test helpers — not a test file
  integration/
    checkout_flow_test.exs  # Spans multiple modules — integration directory
```

## mix test path patterns

Mirroring the structure enables precise `mix test` invocations:

```bash
# Run all tests for the accounts context
mix test test/my_app/accounts/

# Run tests for a specific module
mix test test/my_app/payments/invoice_test.exs
```

## Further Reading

- [ExUnit.Case docs](https://hexdocs.pm/ex_unit/ExUnit.Case.html)
- [Mix test documentation](https://hexdocs.pm/mix/Mix.Tasks.Test.html)
