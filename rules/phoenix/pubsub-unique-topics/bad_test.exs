# EXPECTED: passes
# BAD PRACTICE: Static topic names in async PubSub tests. When tests run
# concurrently, one test's broadcast leaks into another test's mailbox,
# causing spurious assert_receive passes and refute_receive failures.
Mix.install([{:phoenix_pubsub, "~> 2.0"}])

ExUnit.start(autorun: true)

defmodule PubSubStaticTopicsBadTest do
  use ExUnit.Case, async: true

  setup do
    pubsub_name = :"pubsub_bad_static_#{System.unique_integer([:positive])}"
    start_supervised!({Phoenix.PubSub, name: pubsub_name})
    %{pubsub: pubsub_name}
  end

  test "bad: static topic — would leak to concurrent tests if they shared a PubSub", %{pubsub: pubsub} do
    # In a real async test suite with a shared PubSub (MyApp.PubSub),
    # BOTH this test and any concurrent test subscribing to "posts:updates"
    # would receive each other's broadcasts.
    static_topic = "posts:updates"   # ← danger: shared across all concurrent tests

    Phoenix.PubSub.subscribe(pubsub, static_topic)

    Phoenix.PubSub.broadcast(pubsub, static_topic, {:post_published, %{id: 42}})

    # This assert_receive happens to work in isolation, but in a real concurrent
    # suite a different test's broadcast to "posts:updates" could satisfy it
    # — making the test pass even if the code under test never broadcasts.
    assert_receive {:post_published, %{id: 42}}, 500
  end

  test "bad: another test on the same static topic would interfere", %{pubsub: pubsub} do
    # In a real app where two tests use Phoenix.PubSub.subscribe(MyApp.PubSub, "posts:updates"),
    # the first test's broadcast arrives in both test processes' mailboxes.
    static_topic = "posts:updates"

    Phoenix.PubSub.subscribe(pubsub, static_topic)

    # Simulating what happens: broadcast from the previous test "leaks" here.
    # We have to use a separate PubSub instance in this example to stay isolated,
    # but in a real app they'd share MyApp.PubSub and the leak would be real.
    Phoenix.PubSub.broadcast(pubsub, static_topic, {:post_published, %{id: 99}})

    assert_receive {:post_published, _}, 500
  end
end
