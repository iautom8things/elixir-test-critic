---
category: absinthe
title: "Absinthe (GraphQL)"
description: >
  Rules for testing Absinthe GraphQL APIs in Elixir. These rules cover the
  full testing stack: context-first logic separation, efficient schema
  execution, authorization coverage, schema compilation, and query organisation.
rules:
  - test-context-not-resolvers
  - absinthe-run-over-http
  - test-auth-paths
  - prime-schema
  - queries-as-module-attrs
---

# Absinthe (GraphQL) Testing Rules

This category covers testing patterns specific to Absinthe GraphQL APIs. The
rules reflect the layered architecture that benwilson512 (Absinthe co-creator)
recommends: thin resolvers that delegate to context modules, with tests focused
on the right layer of the stack.

## Core Themes

**Test the context, not the resolver.** Resolvers should be thin pass-throughs.
All business logic belongs in context modules that are testable with plain
Elixir function calls. Resolver tests should only verify wiring.

**Choose the right execution layer.** `Absinthe.run/3` executes queries
in-process without HTTP overhead. Use it for schema logic, permissions, and
error handling. Reserve `ConnCase` HTTP tests for transport-level concerns
(auth headers, JSON encoding, Plug middleware).

**Authorization coverage is non-negotiable.** Every protected resolver needs
three tests: the authenticated happy path, an unauthenticated call, and a
wrong-role/wrong-user call. A single missing test leaves a real attack surface
open.

**Prime schemas before tests run.** Absinthe compiles schemas lazily. Add
`Absinthe.Test.prime(MyApp.Schema)` to `test/test_helper.exs` to avoid flaky
timeouts and eliminate compilation cost from the first test.

**Name your queries.** GraphQL query strings defined as `@query` module
attributes are readable, reusable, and single-point-of-edit when the schema
changes. Inline strings in test bodies are noise.

## Rules

| ID | Rule | Severity |
|----|------|----------|
| ETC-ABS-001 | [Test context functions, not resolvers](test-context-not-resolvers/) | recommendation |
| ETC-ABS-002 | [Use Absinthe.run/3 for schema tests, HTTP for integration](absinthe-run-over-http/) | recommendation |
| ETC-ABS-003 | [Test both authorized and unauthorized paths](test-auth-paths/) | critical |
| ETC-ABS-004 | [Call Absinthe.Test.prime/1 in test_helper.exs](prime-schema/) | warning |
| ETC-ABS-005 | [Store GraphQL queries as module attributes](queries-as-module-attrs/) | style |
