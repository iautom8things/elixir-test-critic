---
id: ETC-PHX-005
title: "Use unique topic names in async PubSub tests"
category: phoenix
severity: warning
summary: >
  In async PubSub tests, always generate unique topic names (e.g., using
  `System.unique_integer/1`) so that messages from one test cannot leak into
  another running concurrently on the same PubSub server.
principles:
  - async-default
applies_when:
  - "PubSub tests running with async: true"
  - "Any test that subscribes to a Phoenix.PubSub topic"
  - "Tests that broadcast messages and use assert_receive"
---

# Use unique topic names in async PubSub tests

When PubSub tests run concurrently, multiple test processes may subscribe to
the same topic at the same time. A broadcast in one test will be delivered to
all subscribers — including test processes from other, unrelated tests. This
produces spurious `assert_receive` passes and `refute_receive` failures that
are nearly impossible to reproduce reliably.

The fix is a one-liner: include `System.unique_integer([:positive])` in the
topic string. Each test then operates on a topic that no other test uses.

## Problem

If test A and test B both subscribe to `"posts:updated"` and run concurrently,
a broadcast in test A will be delivered to test B's process mailbox. Test B's
`assert_receive {:post_updated, _}` may pass even if test B never triggered a
broadcast — it just got lucky and caught test A's message. Conversely, an
unexpected message in the mailbox can cause `refute_receive` to fail.

These failures are timing-dependent and rarely reproducible locally, but they
compound on CI where parallelism is higher.

## Detection

- PubSub test topics that are static strings: `"users:updates"`, `"room:1"`, etc.
- Concurrent test modules that share PubSub topic patterns

## Bad

```elixir
defmodule MyApp.PostNotifierTest do
  use ExUnit.Case, async: true

  setup do
    # Every test run subscribes to the SAME topic.
    # Concurrent tests will receive each other's broadcasts.
    Phoenix.PubSub.subscribe(MyApp.PubSub, "posts:updates")
    :ok
  end

  test "broadcasts when a post is published" do
    MyApp.Posts.publish(%Post{id: 1})
    assert_receive {:post_published, %{id: 1}}, 500
  end
end
```

## Good

```elixir
defmodule MyApp.PostNotifierTest do
  use ExUnit.Case, async: true

  setup do
    # Unique topic per test run — no cross-test message leakage.
    post_id = System.unique_integer([:positive])
    topic = "posts:#{post_id}"
    Phoenix.PubSub.subscribe(MyApp.PubSub, topic)
    %{post_id: post_id, topic: topic}
  end

  test "broadcasts when a post is published", %{post_id: post_id} do
    MyApp.Posts.publish(%Post{id: post_id})
    assert_receive {:post_published, %{id: ^post_id}}, 500
  end
end
```

## When This Applies

- All async PubSub tests
- Any test that subscribes to a topic that other tests could also target

## When This Does Not Apply

- Sequential (non-async) test suites — no concurrency, no leakage (though the
  pattern is still good hygiene)
- Tests for a topic that is inherently unique (e.g., `"user:#{user.id}"` where
  `user.id` is unique per test because users are created fresh each time)

## Further Reading

- [Phoenix.PubSub docs](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html)
- [System.unique_integer/1](https://hexdocs.pm/elixir/System.html#unique_integer/1)
