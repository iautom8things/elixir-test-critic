# Organization Rules

Rules for test file structure, readability, and style in Elixir projects.

Well-organised tests are as readable as the code they verify. They follow a
predictable structure, test one thing at a time, avoid testing library internals,
and signal clearly what external resources they require. These rules address the
structure and style of your test suite as a whole.

## Rules in this category

| ID | Rule | Severity |
|----|------|----------|
| [ETC-ORG-001](mirror-lib-structure/) | Mirror lib/ structure in test/ | style |
| [ETC-ORG-002](test-behaviour-not-interactions/) | Test behavior, not interactions | warning |
| [ETC-ORG-003](dont-test-library-code/) | Don't test that libraries work | recommendation |
| [ETC-ORG-004](minimize-setup-blocks/) | Minimize setup block scope | recommendation |
| [ETC-ORG-005](tag-external-dependencies/) | Tag tests requiring external resources | recommendation |

## Guiding principles

**One file per module** — `lib/my_app/accounts/user.ex` maps to
`test/my_app/accounts/user_test.exs`. Use `test/integration/` for multi-module
flows and `test/support/` for shared fixtures.

**Test outcomes, not mechanics** — Assert that calling `A` produced the right
result, not that `A` called `B` internally. Internal call verification breaks on
every refactor, even when behaviour is unchanged.

**Trust your dependencies** — Ecto, Phoenix, Jason, and other well-tested libraries
work correctly. Test only the logic your application contributes on top of them.

**Localise setup** — A `setup` block that runs before tests that don't use its
context forces unnecessary cross-referencing. Inline setup in the test body unless
the same 5+ lines are shared across 3+ tests.

**Make exclusion easy** — Tag tests with `:integration`, `:external_api`, or `:slow`
so that CI pipelines and local developer workflows can selectively run the tests
relevant to the current change.

## ExUnit tag configuration

```elixir
# test/test_helper.exs
ExUnit.configure(exclude: [:integration, :external_api])
ExUnit.start()
```

```bash
# Fast local run (default exclusions apply)
mix test

# Full suite including integration tests
mix test --include integration

# Only external API tests
mix test --only external_api
```
