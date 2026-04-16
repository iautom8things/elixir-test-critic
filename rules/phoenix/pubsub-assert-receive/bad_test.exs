# EXPECTED: passes
# BAD PRACTICE: Using Process.sleep to wait for a broadcast side effect instead
# of subscribing and using assert_receive. The test passes but is slow and flaky.
Mix.install([{:phoenix_pubsub, "~> 2.0"}])

ExUnit.start(autorun: true)

defmodule PubSubSleepBadTest do
  use ExUnit.Case, async: true

  setup do
    pubsub_name = :"pubsub_bad_#{System.unique_integer([:positive])}"
    start_supervised!({Phoenix.PubSub, name: pubsub_name})
    %{pubsub: pubsub_name}
  end

  test "bad: sleeps instead of using assert_receive", %{pubsub: pubsub} do
    topic = "posts:#{System.unique_integer([:positive])}"

    # We never subscribe, so there is no way to verify the message was received.
    # Instead, we rely on a side effect (an Agent counter) updated by a subscriber.
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    # Simulate a subscriber process that increments the agent when it gets the message
    subscriber_pid = spawn(fn ->
      Phoenix.PubSub.subscribe(pubsub, topic)
      receive do
        {:post_published, _} -> Agent.update(agent, &(&1 + 1))
      end
    end)

    # Give subscriber time to subscribe (already a code smell)
    Process.sleep(10)

    Phoenix.PubSub.broadcast(pubsub, topic, {:post_published, %{id: 1}})

    # Bad: sleeping to hope the broadcast was processed
    Process.sleep(100)

    # Bad: asserting on side effect (agent counter) rather than the message itself
    count = Agent.get(agent, & &1)
    assert count == 1

    # Clean up
    Process.exit(subscriber_pid, :kill)
    Agent.stop(agent)
  end

  test "bad: no subscription — broadcast is completely untested", %{pubsub: pubsub} do
    topic = "posts:#{System.unique_integer([:positive])}"

    # We call broadcast but never subscribe or verify the message was received.
    # The test passes vacuously.
    Phoenix.PubSub.broadcast(pubsub, topic, {:post_published, %{id: 2}})

    # Asserting only on database state (simulated here as a plain map)
    # — the broadcast itself is untested.
    db_state = %{status: :published}
    assert db_state.status == :published
  end
end
