# Elixir Test Critic — Foundational Principles

These ten principles, synthesized from the Elixir community's writing and talks
on testing, form the philosophical foundation for every rule in this knowledge base.

Every rule references one or more of these principles by short name in its frontmatter.

---

## 1. Purity Separation (`purity-separation`)

Separate pure logic from side effects. Pure functions are trivially testable —
they take inputs and return outputs. Side effects (database writes, HTTP calls,
process messages) require infrastructure. Structure your code so the core logic
is pure and the side-effecting shell is thin.

**Testing implication:** Test pure logic with simple unit tests. Test side effects
at the boundary with integration tests. Never mix the two.

## 2. Contracts First (`contracts-first`)

Define explicit contracts (behaviours) for boundaries between your code and
external systems. The contract IS the API surface — test against it, mock against it.

**Testing implication:** Mock behaviours, not modules. If there's no behaviour,
there's no contract, and mocking is guesswork.

## 3. Mock as Noun (`mock-as-noun`)

A mock is a noun (a thing that implements a contract), not a verb (an action you
perform on a function). Mox enforces this — you define a mock module that
implements a behaviour. You don't "mock" a function call.

**Testing implication:** Use Mox. Define behaviours. Inject dependencies.
Avoid Mimic/Patch-style monkey-patching that mocks functions as a verb.

## 4. Integration Required (`integration-required`)

For every mock, there must be a corresponding integration test that exercises
the real implementation. Mocks prove your code handles the contract correctly;
integration tests prove the real implementation fulfills the contract.

**Testing implication:** If you mock an HTTP client, also write a test that
hits the real (or sandboxed) HTTP endpoint.

## 5. Async Default (`async-default`)

Tests should run concurrently by default (`async: true`). Sequential tests
are a code smell — they usually indicate shared mutable state.

**Testing implication:** Design for isolation. Use process-specific data,
unique identifiers, and ownership-based resource management (Ecto sandbox,
Mox allowances).

## 6. Public Interface (`public-interface`)

Test the public API of a module, not its internal implementation. If a function
is not exported, it's not part of the contract and should not be tested directly.

**Testing implication:** Don't use `:sys.get_state/1` to peek at GenServer state.
Don't test private functions through `Module.__info__/1` tricks. Test what the
module promises to its callers.

## 7. Thin Processes (`thin-processes`)

GenServers and other OTP processes should be thin wrappers around pure logic
modules. The process manages state and concurrency; the logic module does the work.

**Testing implication:** Test the logic module directly with unit tests.
Test the GenServer primarily for process lifecycle, message ordering, and
concurrency concerns.

## 8. Honest Data (`honest-data`)

Test data should be realistic and honest. Don't use `%{id: 1}` when your
system expects a full user struct. Don't hardcode the same email in every test.
Fake data masks real edge cases.

**Testing implication:** Use unique values per test. Build complete data
structures. Prefer factory functions that generate unique, valid data
over copy-pasted fixtures.

## 9. Boundary Testing (`boundary-testing`)

Test at the boundaries of your system — where your code meets the database,
the network, the filesystem, or another process. These boundaries are where
bugs hide.

**Testing implication:** Integration tests at boundaries catch real failures
that unit tests miss. A changeset test without a database can't catch
constraint violations. A controller test without a router can't catch
routing bugs.

## 10. Assert, Don't Sleep (`assert-not-sleep`)

Never use `Process.sleep/1` to wait for async operations in tests. Use
`assert_receive/3` with a timeout, or force synchronization through the
process's own API.

**Testing implication:** Replace `Process.sleep(100); assert ...` with
`assert_receive :message, 1000` or `GenServer.call(pid, :sync)` to force
the process to process its mailbox.
