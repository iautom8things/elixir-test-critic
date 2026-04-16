---
category: phoenix
title: "Phoenix"
description: >
  Rules for testing Phoenix applications: controllers, ConnCase, plugs, and PubSub.
  These rules focus on the HTTP boundary and the message-passing patterns that
  Phoenix provides.
rules:
  - test-http-response-not-internals
  - verified-routes-in-tests
  - conncase-async-safe
  - pubsub-assert-receive
  - pubsub-unique-topics
---

# Phoenix Testing Rules

This category covers testing patterns specific to Phoenix applications. The rules
address the most common mistakes teams make when writing controller tests, plug
tests, and PubSub tests.

## Core Themes

**Test the HTTP contract, not internals.** A Phoenix controller is an HTTP
boundary. Its public interface is the response it returns: status code, body,
headers, redirect location. Asserting on `conn.assigns` or internal function
calls couples tests to implementation details and makes refactoring expensive.

**Use verified routes everywhere.** The `~p` sigil is not just for application
code. Using it in tests means route renames and removals surface as compile
errors rather than runtime 404s.

**Async is safe with ConnCase.** Ecto's SQL sandbox supports per-test transaction
isolation, making `async: true` safe for all ConnCase tests. Omitting it is a
performance regression with no correctness benefit.

**PubSub messages are testable directly.** Subscribe the test process to the
topic, trigger the action, use `assert_receive`. No sleeping. No indirect
side-effect assertions.

**Unique topics prevent message leakage.** In async suites, static PubSub topic
names cause cross-test message pollution. A single `System.unique_integer/1`
call in the topic name eliminates the problem entirely.

## Rules

| ID | Rule | Severity |
|----|------|----------|
| ETC-PHX-001 | [Test HTTP responses, not controller internals](test-http-response-not-internals/) | warning |
| ETC-PHX-002 | [Use verified routes (~p) in tests](verified-routes-in-tests/) | recommendation |
| ETC-PHX-003 | [ConnCase tests are async-safe by default](conncase-async-safe/) | recommendation |
| ETC-PHX-004 | [Subscribe and assert_receive for PubSub messages](pubsub-assert-receive/) | warning |
| ETC-PHX-005 | [Use unique topic names in async tests](pubsub-unique-topics/) | warning |
