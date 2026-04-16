# Isolation — Test Isolation & Async Safety

## Scope

Rules in this category address the correctness of concurrent test execution. They
cover the specific patterns that cause async tests to interfere with each other:
shared global state (Application env, ETS, persistent_term), non-unique test data
that collides under uniqueness constraints, Ecto SQL Sandbox ownership and allowance
patterns, and the process boundary behaviour of `on_exit` callbacks.

These rules apply to any project running async tests and are especially critical
in projects using Ecto, where the database is the most common source of shared state.

## Rules

| ID | Slug | Title | Severity |
|----|------|-------|----------|
| ETC-ISO-001 | no-app-put-env-async | Never use Application.put_env in async tests | critical |
| ETC-ISO-002 | unique-test-data | Generate unique values for constrained fields | critical |
| ETC-ISO-003 | no-shared-ets-async | Do not share ETS/persistent_term in async tests | critical |
| ETC-ISO-004 | sandbox-ownership-strategy | Choose sandbox mode and ownership based on process needs | warning |
| ETC-ISO-005 | on-exit-process-boundary | on_exit runs in a separate process | warning |
