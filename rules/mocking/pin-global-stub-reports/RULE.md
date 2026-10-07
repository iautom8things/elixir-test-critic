---
id: ETC-MOCK-010
title: "Make global-mode stubs report an id the test owns"
category: mocking
severity: warning
summary: >
  In global mode (`set_mimic_global`, `Mox.set_mox_global`) any process can reach
  the test's stubs, including one leaked from an earlier test. A stub that sends
  the test a message should include an id the test created, and the assertion
  should pin it.
principles:
  - mock-as-noun
  - async-default
related_rules:
  - ETC-MOCK-004
  - ETC-ISO-006
  - ETC-CORE-004
applies_when:
  - "A test uses Mox or Mimic in global mode"
  - "A stub reports back with send(test_pid, ...) and the test asserts on that message"
  - "The code under test runs in processes the test did not start (sessions, workers, agents)"
does_not_apply_when:
  - "Private mode, where only the test process and its $callers can reach the stub"
  - "The stub returns a value and sends nothing to the test"
tags: [mox, mimic, global-mode, flaky]
---

# Make global-mode stubs report an id the test owns

Global mode routes every call to the current test's stubs, whichever process
makes it. When a stub reports to the test, put an identifier the test created
in the message and pin it in the assertion. Then a stray process can't answer
for the code under test.

## Problem

Tests switch to global mode when the code under test runs in processes that
can't be allowed one by one: a session under a Horde supervisor, an agent
started by a library, a worker pool. Global mode is fine while those are the
only callers. It breaks once a process left over from an earlier test (see
ETC-ISO-006) makes the same call. The stub runs for it, sends the test a
message with the stray's data, and an assertion like
`assert_receive {:tool_context, context}` takes whichever message arrives
first.

The failure looks like a bug in the code under test. One suite's "turn source
comes from the turn metadata" test got `turn_source: nil` from a review
follow-up session that a LiveView test had started minutes earlier. It also
saw a `Mox.UnexpectedCallError` from a third session. The test under suspicion
had nothing to do with either.

## Detection

- `setup :set_mimic_global`, `setup :set_mox_global` or `Mox.set_mox_global()`,
  plus a stub body that calls `send(test_pid, {...})`.
- A matching `assert_receive {:tag, payload}` or `refute_receive {:tag, _}` with
  no pinned identifier (`^id`) in the pattern.
- The code under test passes an id through the stubbed call (a session id,
  request id or job id) that the stub ignores.

## Bad

```elixir
setup :set_mimic_global

test "the turn carries its source", %{sid: sid} do
  test_pid = self()

  Mimic.stub(Engine, :ask_sync, fn _pid, _message, opts ->
    send(test_pid, {:tool_context, opts[:tool_context]})
    {:ok, "done"}
  end)

  :ok = Session.ask_async(sid, "hello", %{source: :verify})
  # Any session still alive from an earlier test can satisfy this.
  assert_receive {:tool_context, %{turn_source: :verify}}, 5_000
end
```

## Good

```elixir
setup :set_mimic_global

test "the turn carries its source", %{sid: sid} do
  test_pid = self()

  Mimic.stub(Engine, :ask_sync, fn _pid, _message, opts ->
    context = opts[:tool_context]
    send(test_pid, {:tool_context, context[:session_id], context})
    {:ok, "done"}
  end)

  :ok = Session.ask_async(sid, "hello", %{source: :verify})
  assert_receive {:tool_context, ^sid, %{turn_source: :verify}}, 5_000
end
```

Pinning makes a stray call harmless to this assertion. It does not stop the
stray. Fix the leak as well (ETC-ISO-006), because the stray still runs real
code against the test's database and mocks.

## When This Applies

- Every global-mode stub that reports to the test process.
- `refute_receive` on the same tag. Without the pin, a stray message fails the
  refutation at random.

## When This Does Not Apply

- **Private mode**: only the test process and processes carrying it in
  `$callers` reach the stub, so a stray cannot.
- **Stubs that only return values**: nothing is sent to the test, so there is
  nothing to misattribute. A stray call can still raise
  `Mox.UnexpectedCallError` in the stray's own process.

## Further Reading

- [Mox — global mode](https://hexdocs.pm/mox/Mox.html#module-global-mode)
- [Mimic — private and global mode](https://hexdocs.pm/mimic/readme.html#private-and-global-mode)
