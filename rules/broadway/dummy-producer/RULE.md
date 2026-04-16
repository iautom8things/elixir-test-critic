---
id: ETC-BWAY-001
title: "Use Broadway.DummyProducer in test config"
category: broadway
severity: recommendation
summary: >
  Configure Broadway.DummyProducer as the producer module in your test environment.
  It emits no messages on its own, giving tests full control: messages arrive only
  when your test explicitly calls Broadway.test_message/3 or Broadway.test_batch/3.
principles:
  - purity-separation
  - boundary-testing
applies_when:
  - "Writing integration tests for a Broadway pipeline"
  - "Configuring Broadway in a test environment"
  - "Needing deterministic, on-demand message delivery in tests"
does_not_apply_when:
  - "Testing handler functions in isolation — use handler-isolation (ETC-BWAY-004) instead"
  - "Load-testing or performance benchmarking the pipeline"
related_rules:
  - ETC-BWAY-002
  - ETC-BWAY-003
  - ETC-BWAY-004
  - ETC-MOCK-007
---

# Use Broadway.DummyProducer in test config

Broadway pipelines pull messages from an external source (SQS, RabbitMQ, Kafka, etc.).
In tests you don't want real messages arriving asynchronously and out of your control.
`Broadway.DummyProducer` is Broadway's built-in test producer: it starts silently,
never emits messages on its own, and lets you inject exactly the messages your test
needs via `Broadway.test_message/3` and `Broadway.test_batch/3`.

## The Pattern

Swap the producer module based on the Mix environment (or an application config key):

```elixir
# In your Broadway pipeline module
defmodule MyApp.Pipeline do
  use Broadway

  def start_link(opts) do
    producer = Keyword.get(opts, :producer, MyApp.SQSProducer)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {producer, []},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        db: [concurrency: 1, batch_size: 10]
      ]
    )
  end

  # ... handle_message/3, handle_batch/4 ...
end
```

```elixir
# In your test
defmodule MyApp.PipelineTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, pid} = MyApp.Pipeline.start_link(producer: Broadway.DummyProducer)
    on_exit(fn -> Broadway.stop(pid) end)
    {:ok, pid: pid}
  end

  test "processes a message successfully", %{pid: pid} do
    ref = Broadway.test_message(pid, "hello")
    assert_receive {:ack, ^ref, [%{data: "hello"}], []}
  end
end
```

## Why DummyProducer

| Real producer in tests | DummyProducer in tests |
|---|---|
| Requires live connection to SQS/Kafka/etc. | No external dependency |
| Messages arrive at unpredictable times | Messages arrive only when you call test_message/3 |
| Flaky due to network, backpressure, ordering | Deterministic |
| Slow (network round-trips) | Fast (in-process) |

## Config-Based Swapping

An alternative to passing the producer as a start option is to read it from application config:

```elixir
# config/test.exs
config :my_app, :broadway_producer, Broadway.DummyProducer

# In your pipeline
producer_mod = Application.fetch_env!(:my_app, :broadway_producer)
```

Both approaches work; the `start_link` option pattern is more amenable to async tests
since each test can start its own isolated pipeline instance.

## Detection

A pipeline that hardcodes its real producer module (SQS, RabbitMQ, etc.) in the
`start_link` call with no mechanism for swapping it in tests. Symptoms: tests that
must mock the producer at the module level, or tests that connect to real message
brokers.

## Further Reading

- [Broadway.DummyProducer docs](https://hexdocs.pm/broadway/Broadway.DummyProducer.html)
- [Broadway testing guide](https://hexdocs.pm/broadway/Broadway.html#module-testing)
- [Broadway.test_message/3](https://hexdocs.pm/broadway/Broadway.html#test_message/3)
