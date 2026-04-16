---
id: ETC-BWAY-004
title: "Unit test handler functions in isolation"
category: broadway
severity: recommendation
summary: >
  handle_message/3, handle_batch/4, and handle_failed/2 are plain Elixir functions.
  Test them by constructing Broadway.Message structs directly and calling the functions
  without starting the full pipeline. This is the most important Broadway testing rule —
  the majority of Broadway business logic tests should live here.
principles:
  - purity-separation
  - thin-processes
applies_when:
  - "Testing the transformation logic inside handle_message/3"
  - "Testing batch processing decisions in handle_batch/4"
  - "Testing error recovery logic in handle_failed/2"
  - "Unit testing a Broadway pipeline module quickly and without external dependencies"
does_not_apply_when:
  - "Testing pipeline configuration, routing, or acknowledgment behaviour — use test_message/3 (ETC-BWAY-002)"
  - "Testing that the full pipeline wires up correctly end-to-end"
  - "Testing full pipeline integration with acknowledgments — use DummyProducer (ETC-BWAY-001) and ack assertions (ETC-BWAY-003)"
related_rules:
  - ETC-BWAY-001
  - ETC-OTP-001
  - ETC-ABS-001
  - ETC-CORE-001
---

# Unit test handler functions in isolation

Broadway's handler callbacks — `handle_message/3`, `handle_batch/4`, and
`handle_failed/2` — are plain Elixir functions. They take structs and return structs.
They have no hidden state and no process requirements. This means you can call them
directly in a test without starting any pipeline at all.

This is the single most impactful Broadway testing insight. Starting a full pipeline
for every logic test is slow and adds unnecessary setup complexity. For the business
logic living inside handlers, direct function calls are faster, simpler, and equally
correct.

## Constructing Broadway.Message Structs

```elixir
# Minimal message
msg = %Broadway.Message{
  data: "hello world",
  acknowledger: Broadway.NoopAcknowledger.init()
}

# Message with metadata
msg = %Broadway.Message{
  data: ~s({"user_id": 42}),
  metadata: %{source: "sqs", queue: "events"},
  acknowledger: Broadway.NoopAcknowledger.init()
}
```

`Broadway.NoopAcknowledger` is Broadway's built-in no-op acknowledger for use in
tests — it satisfies the acknowledger contract without sending any ack messages.

## Good: Testing handle_message/3 Directly

```elixir
defmodule MyApp.EventPipelineHandlerTest do
  use ExUnit.Case, async: true

  alias MyApp.EventPipeline

  defp new_message(data, metadata \\ %{}) do
    %Broadway.Message{
      data: data,
      metadata: metadata,
      acknowledger: Broadway.NoopAcknowledger.init()
    }
  end

  test "handle_message/3 parses valid JSON and sets data" do
    msg = new_message(~s({"event": "purchase", "amount": 99}))
    result = EventPipeline.handle_message(:default, msg, %{})

    assert result.data == %{"event" => "purchase", "amount" => 99}
    assert result.status == :ok
  end

  test "handle_message/3 fails message on invalid JSON" do
    msg = new_message("not-json")
    result = EventPipeline.handle_message(:default, msg, %{})

    assert {:failed, _reason} = result.status
  end
end
```

## Good: Testing handle_batch/4 Directly

```elixir
defmodule MyApp.EventPipelineBatchTest do
  use ExUnit.Case, async: true

  alias MyApp.EventPipeline

  test "handle_batch/4 inserts all messages into the database" do
    messages =
      Enum.map(1..3, fn i ->
        %Broadway.Message{
          data: %{"id" => i, "event" => "purchase"},
          acknowledger: Broadway.NoopAcknowledger.init()
        }
      end)

    results = EventPipeline.handle_batch(:db, messages, %Broadway.BatchInfo{}, %{})

    # handle_batch/4 returns the (possibly modified) message list
    assert length(results) == 3
    assert Enum.all?(results, fn m -> m.status == :ok end)
  end
end
```

## Bad: Starting the Pipeline for Every Logic Test

```elixir
defmodule MyApp.EventPipelineBadTest do
  use ExUnit.Case, async: false

  # BAD: Spinning up the full pipeline just to test handle_message parsing logic.
  # This is slow, can't run async, and requires DummyProducer setup and teardown.
  setup do
    {:ok, pid} = MyApp.EventPipeline.start_link(producer: Broadway.DummyProducer)
    on_exit(fn -> Broadway.stop(pid) end)
    {:ok, pid: pid}
  end

  test "parses JSON in handle_message/3", %{pid: pid} do
    ref = Broadway.test_message(pid, ~s({"event": "purchase", "amount": 99}))
    assert_receive {:ack, ^ref, [msg], []}
    assert msg.data["amount"] == 99
  end
end
```

## What Belongs Where

| Logic to test | Approach |
|---|---|
| Parsing, transformation, validation in handle_message/3 | Direct function call (this rule) |
| Batch insert logic in handle_batch/4 | Direct function call (this rule) |
| Error recovery in handle_failed/2 | Direct function call (this rule) |
| Full ack/nack behaviour through the pipeline | test_message/3 + assert_receive (ETC-BWAY-002/003) |
| Pipeline configuration (concurrency, batchers) | Integration test with DummyProducer (ETC-BWAY-001) |

## The Broadway.Message Acknowledger Field

The `acknowledger` field is required on all Broadway messages. For isolation tests,
use `Broadway.NoopAcknowledger.init()`. Alternatively, you can use
`{Broadway.CallerAcknowledger, {self(), make_ref()}, nil}` if you want the ack
message sent to your test process even without a running pipeline — but for pure
handler logic tests, the noop acknowledger is simpler.

## Detection

- Test files that start a Broadway pipeline (`Broadway.start_link`) for every test case,
  even when testing pure transformation logic
- Test setup blocks with `on_exit(fn -> Broadway.stop(pid) end)` in files that only
  verify message data transformations
- Pipeline tests marked `async: false` solely because of pipeline startup overhead

## Further Reading

- [Broadway.Message struct](https://hexdocs.pm/broadway/Broadway.Message.html)
- [Broadway.NoopAcknowledger](https://hexdocs.pm/broadway/Broadway.NoopAcknowledger.html)
- [Broadway.BatchInfo](https://hexdocs.pm/broadway/Broadway.BatchInfo.html)
