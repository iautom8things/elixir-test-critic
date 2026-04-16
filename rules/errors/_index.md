# Errors — Error Handling & Exception Testing

## Scope

Rules in this category cover the correct testing of error paths in Elixir code.
Elixir functions signal failure in two primary ways: raising exceptions and returning
tagged error tuples (`{:error, reason}`). Both mechanisms require dedicated testing
patterns that go beyond the happy path.

These rules apply to any function that can fail — Ecto operations, HTTP clients,
parsers, `with` chains, and any function guarded by conditions that raise. They
complement the Core rules by focusing specifically on what happens when things go wrong.

## Rules

| ID | Slug | Title | Severity |
|----|------|-------|----------|
| ETC-ERR-001 | assert-raise-with-message | Use 3-arity assert_raise with message matching | warning |
| ETC-ERR-002 | test-error-tuples | Test both success and error return paths | warning |
| ETC-ERR-003 | test-with-clause-errors | Test every non-match branch in with statements | warning |
