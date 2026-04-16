# Mocking Rules

Rules for using Mox, Bypass, Req.Test, and dependency injection correctly.

The Elixir community has a principled approach to mocking: mocks are nouns
(modules implementing behaviours), not verbs (actions performed on functions).
These rules encode that philosophy and the practical patterns that flow from it.

## Rules

| ID | Slug | Severity | Summary |
|----|------|----------|---------|
| ETC-MOCK-001 | [behaviour-before-mock](behaviour-before-mock/RULE.md) | critical | Define a behaviour before creating a mock |
| ETC-MOCK-002 | [mock-at-boundary-only](mock-at-boundary-only/RULE.md) | warning | Only mock at system boundaries |
| ETC-MOCK-003 | [expect-vs-stub](expect-vs-stub/RULE.md) | recommendation | Use expect when verifying calls, stub for setup |
| ETC-MOCK-004 | [verify-on-exit](verify-on-exit/RULE.md) | critical | Always verify mock expectations |
| ETC-MOCK-005 | [bypass-for-http-layer](bypass-for-http-layer/RULE.md) | recommendation | Use Bypass when testing HTTP behavior |
| ETC-MOCK-006 | [req-test-for-business-logic](req-test-for-business-logic/RULE.md) | recommendation | Use Req.Test for business logic over HTTP |
| ETC-MOCK-007 | [prefer-dependency-injection](prefer-dependency-injection/RULE.md) | recommendation | Prefer dependency injection over application config |
| ETC-MOCK-008 | [integration-test-per-mock](integration-test-per-mock/RULE.md) | warning | Write at least one integration test per mocked boundary |
| ETC-MOCK-009 | [dont-mock-pure-functions](dont-mock-pure-functions/RULE.md) | warning | Don't mock your own pure functions |

## Key Principles

- **Contracts First** — Define a `@behaviour` before creating any Mox mock. The contract IS the API.
- **Mock as Noun** — A mock is a module implementing a behaviour, not a function interception.
- **Boundary Testing** — Only mock at the edges of your system (HTTP, email, payment, DB).
- **Purity Separation** — Pure functions need no mocking; test them directly.
- **Integration Required** — Every mocked boundary needs at least one integration test of the real adapter.

## Tool Selection Guide

| Scenario | Tool |
|----------|------|
| Swapping an adapter (email, SMS, payment) | Mox with a behaviour |
| Testing HTTP status codes, headers, request shape | Bypass |
| Testing business logic that uses Req | Req.Test |
| Injecting a dependency cleanly | Function argument (DI) |
| Testing a pure transformation function | Direct call — no mock |
