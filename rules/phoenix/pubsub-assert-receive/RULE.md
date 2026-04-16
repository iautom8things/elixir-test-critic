---
id: ETC-PHX-004
title: "Subscribe and assert_receive for PubSub messages"
category: phoenix
severity: warning
summary: >
  To test PubSub broadcasts, subscribe to the topic in the test process, trigger
  the action that broadcasts, then use `assert_receive` to verify the message
  arrived. Never rely on side effects or `Process.sleep` to infer that a broadcast
  occurred.
principles:
  - assert-not-sleep
  - public-interface
applies_when:
  - "Testing any code path that calls Phoenix.PubSub.broadcast/3"
  - "Testing LiveView or channel event handlers that emit broadcasts"
  - "Any test that needs to verify a message was sent to a PubSub topic"
---

# Subscribe and assert_receive for PubSub messages

Phoenix.PubSub delivers messages asynchronously to subscribing processes.
The correct testing pattern is:

1. Subscribe the test process to the topic before the action
2. Trigger the action that broadcasts
3. Use `assert_receive` (with a timeout) to verify the message arrived

This is explicit, deterministic, and avoids sleeping.

## Problem

Without subscribing and asserting on the message directly, developers resort
to one of two bad patterns:

- **Process.sleep**: sleep long enough to hope the broadcast arrived, then
  check a side effect. Flaky under load and slow by definition.
- **Side-effect assertions only**: assert that a database row changed or a
  counter incremented, ignoring whether PubSub ever delivered the message.
  The broadcast is a public output of the function — it should be tested directly.

## Detection

- `Process.sleep` followed by an indirect assertion near PubSub code
- Tests that broadcast to a topic but never call `Phoenix.PubSub.subscribe` and `assert_receive`
- Tests that assert only on database state after a broadcast event

## Bad

```elixir
test "notifies subscribers when a post is published" do
  post = insert(:post, status: :draft)

  MyApp.Posts.publish(post)

  # Bad: sleeping to hope the broadcast arrived
  Process.sleep(100)

  # Bad: asserting only on DB side effect, not on the broadcast itself
  updated = MyApp.Repo.get!(Post, post.id)
  assert updated.status == :published
end
```

## Good

```elixir
test "notifies subscribers when a post is published" do
  post = insert(:post, status: :draft)

  # Subscribe before triggering the action
  Phoenix.PubSub.subscribe(MyApp.PubSub, "posts:#{post.id}")

  MyApp.Posts.publish(post)

  # Assert the broadcast arrived
  assert_receive {:post_published, %{id: ^post.id}}, 500
end
```

## When This Applies

- Any test verifying that a PubSub broadcast was sent
- Tests for `handle_info` callbacks that react to PubSub messages

## When This Does Not Apply

- Testing that a subscriber *reacts* to a message when you control the sender —
  send the message directly with `send(pid, msg)` and assert on the reaction
- Integration tests that verify end-to-end database changes only (and broadcast
  verification is out of scope for that specific test)

## Further Reading

- [Phoenix.PubSub docs](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html)
- [ExUnit assert_receive/3](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_receive/3)
