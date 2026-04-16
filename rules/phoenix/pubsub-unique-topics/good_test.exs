# EXPECTED: passes
Mix.install([{:phoenix_pubsub, "~> 2.0"}])

ExUnit.start(autorun: true)

defmodule PubSubUniqueTopicsGoodTest do
  use ExUnit.Case, async: true

  setup do
    pubsub_name = :"pubsub_unique_good_#{System.unique_integer([:positive])}"
    start_supervised!({Phoenix.PubSub, name: pubsub_name})
    %{pubsub: pubsub_name}
  end

  test "unique topic isolates this test's messages from others", %{pubsub: pubsub} do
    # System.unique_integer generates a value unique per BEAM session —
    # no two concurrent tests will share this topic.
    unique_id = System.unique_integer([:positive])
    topic = "posts:#{unique_id}"

    Phoenix.PubSub.subscribe(pubsub, topic)

    Phoenix.PubSub.broadcast(pubsub, topic, {:post_published, %{id: unique_id}})

    # This assert_receive will only see messages for THIS test's topic.
    assert_receive {:post_published, %{id: ^unique_id}}, 500
  end

  test "second test uses its own unique topic", %{pubsub: pubsub} do
    unique_id = System.unique_integer([:positive])
    topic = "posts:#{unique_id}"

    Phoenix.PubSub.subscribe(pubsub, topic)

    Phoenix.PubSub.broadcast(pubsub, topic, {:post_archived, %{id: unique_id}})

    assert_receive {:post_archived, %{id: ^unique_id}}, 500
  end

  test "refute_receive is reliable with unique topics", %{pubsub: pubsub} do
    unique_id = System.unique_integer([:positive])
    my_topic = "posts:#{unique_id}"
    other_topic = "posts:#{unique_id + 1_000_000}"

    Phoenix.PubSub.subscribe(pubsub, my_topic)

    # Broadcast to a different topic — should not arrive in this test's mailbox
    Phoenix.PubSub.broadcast(pubsub, other_topic, {:post_published, %{id: 999}})

    refute_receive {:post_published, _}, 100
  end
end
