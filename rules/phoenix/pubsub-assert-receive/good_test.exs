# EXPECTED: passes
Mix.install([{:phoenix_pubsub, "~> 2.0"}])

ExUnit.start(autorun: true)

defmodule PubSubAssertReceiveGoodTest do
  use ExUnit.Case, async: true

  setup do
    pubsub_name = :"pubsub_good_#{System.unique_integer([:positive])}"
    start_supervised!({Phoenix.PubSub, name: pubsub_name})
    %{pubsub: pubsub_name}
  end

  test "subscribe before broadcast, assert_receive after", %{pubsub: pubsub} do
    topic = "posts:#{System.unique_integer([:positive])}"

    # Step 1: subscribe the test process to the topic
    Phoenix.PubSub.subscribe(pubsub, topic)

    # Step 2: trigger the action that broadcasts
    Phoenix.PubSub.broadcast(pubsub, topic, {:post_published, %{id: 42, title: "Hello"}})

    # Step 3: assert the message arrived — no sleep needed
    assert_receive {:post_published, %{id: 42, title: "Hello"}}, 500
  end

  test "assert_receive with pattern match on specific fields", %{pubsub: pubsub} do
    post_id = System.unique_integer([:positive])
    topic = "posts:#{post_id}"

    Phoenix.PubSub.subscribe(pubsub, topic)

    # Simulate what MyApp.Posts.publish/1 would broadcast
    Phoenix.PubSub.broadcast(pubsub, topic, {:post_updated, %{id: post_id, status: :published}})

    assert_receive {:post_updated, %{status: :published}}, 500
  end

  test "no message received when broadcast targets a different topic", %{pubsub: pubsub} do
    Phoenix.PubSub.subscribe(pubsub, "posts:mine")

    # Broadcast goes to a different topic — test process should NOT receive it
    Phoenix.PubSub.broadcast(pubsub, "posts:other", {:post_published, %{id: 99}})

    refute_receive {:post_published, _}, 100
  end
end
