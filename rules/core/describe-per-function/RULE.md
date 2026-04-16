---
id: ETC-CORE-002
title: "One describe block per public function"
category: core
severity: style
summary: >
  Group tests for each public function inside a dedicated `describe` block named
  after that function. This makes it obvious which function is broken when tests
  fail and keeps the test module navigable as the module under test grows.
principles:
  - public-interface
applies_when:
  - "Testing a module with more than one public function"
  - "Any test module where tests cover multiple distinct behaviours of an API"
---

# One describe block per public function

Use one `describe` block per public function in the module under test. Name the block
after the function (e.g., `describe "create/2"` or `describe "fetch_user/1"`). This
creates a clear mapping between the code under test and the test coverage.

## Problem

When all tests for a module sit at the top level without `describe` grouping, the
connection between each test and the function it exercises is implicit. Failure
output says `MyModuleTest — error on line 47` without indicating which function
broke. As the module grows, the flat list of tests becomes hard to scan.

Nested `describe` blocks (grouping by scenario inside a function group) are acceptable
but should not substitute for the function-level structure. The function-level
`describe` is the minimum structure that every test module with multiple public
functions should have.

## Detection

- Test modules with more than two `test` blocks and zero `describe` blocks
- Multiple tests for the same function scattered through a flat list
- `describe` blocks named after scenarios rather than functions (e.g., `describe "when logged in"` as the only grouping)

## Bad

```elixir
defmodule MyApp.AccountTest do
  use ExUnit.Case, async: true

  # No describe grouping — which function does each test target?
  test "creates account with valid attrs" do ... end
  test "fails with missing email" do ... end
  test "returns account by id" do ... end
  test "returns nil when not found" do ... end
end
```

## Good

```elixir
defmodule MyApp.AccountTest do
  use ExUnit.Case, async: true

  describe "create/1" do
    test "returns ok tuple with valid attrs" do ... end
    test "returns error changeset with missing email" do ... end
  end

  describe "get/1" do
    test "returns the account when found" do ... end
    test "returns nil when not found" do ... end
  end
end
```

## When This Applies

- Any test module covering two or more public functions
- Modules where you want test output to clearly attribute failures to functions

## When This Does Not Apply

- Test modules for a single-function module — a `describe` block adds no value
  when there's nothing to disambiguate
- Integration or end-to-end tests that exercise a whole workflow rather than a single function

## Further Reading

- [ExUnit.Case describe/2 docs](https://hexdocs.pm/ex_unit/ExUnit.Case.html#describe/2)
- [Elixir Testing with ExUnit — Álvaro Paço](https://dashbit.co/blog/a-tour-of-meilisearch-in-elixir)
