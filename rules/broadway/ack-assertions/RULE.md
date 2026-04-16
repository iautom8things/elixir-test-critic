---
id: ETC-BWAY-003
title: "Assert on acknowledgment messages for correctness"
category: broadway
severity: recommendation
summary: >
  The canonical Broadway test assertion is assert_receive {:ack, ^ref, successful, failed}.
  Always check both lists: successful messages confirm correct processing, and failed messages
  confirm expected error handling. Pinning the ref prevents false positives from unrelated acks.
principles:
  - public-interface
  - boundary-testing
applies_when:
  - "Verifying a message was processed without errors"
  - "Verifying a message was intentionally failed or retried"
  - "Testing that error handling marks messages as failed rather than crashing"
does_not_apply_when:
  - "Testing handler function logic in isolation — no pipeline needed (ETC-BWAY-004)"
  - "Testing only that a pipeline starts and shuts down cleanly"
related_rules:
  - ETC-BWAY-001
  - ETC-BWAY-002
  - ETC-CORE-004
---

# Assert on acknowledgment messages for correctness

Broadway's acknowledgment system is your primary observable output in pipeline tests.
When a message completes processing (successfully or not), the pipeline sends an `:ack`
message back to the test process (when using `Broadway.DummyProducer`):

```
{:ack, ref, successful_messages, failed_messages}
```

- `ref` — the reference returned by `test_message/3` or `test_batch/3`
- `successful_messages` — list of `Broadway.Message` structs that completed without error
- `failed_messages` — list of `Broadway.Message` structs that were explicitly failed

## The Canonical Assertion Pattern

```elixir
ref = Broadway.test_message(pid, data)
assert_receive {:ack, ^ref, successful, failed}
```

The `^ref` pin is essential. Without it you might match an ack from a different message,
making the test pass spuriously.

## Asserting on Successful Processing

```elixir
test "valid message is processed and acked successfully", %{pid: pid} do
  ref = Broadway.test_message(pid, ~s({"event": "purchase", "amount": 99}))

  assert_receive {:ack, ^ref, successful, failed}
  assert [msg] = successful
  assert failed == []
  # Optionally inspect transformed data:
  assert msg.data["amount"] == 99
end
```

## Asserting on Expected Failures

When your `handle_message/3` calls `Broadway.Message.failed/2`, the message lands in
the `failed` list. This is the correct way to model unrecoverable messages — test it
explicitly:

```elixir
test "malformed JSON is failed with an error reason", %{pid: pid} do
  ref = Broadway.test_message(pid, "not-valid-json")

  assert_receive {:ack, ^ref, successful, failed}
  assert successful == []
  assert [msg] = failed
  # Broadway.Message stores the failure reason
  assert {:failed, "invalid JSON"} = msg.status
end
```

## The Full Pipeline Processor

```elixir
defmodule MyApp.EventPipeline do
  use Broadway

  def handle_message(_processor, %Broadway.Message{data: data} = msg, _context) do
    case Jason.decode(data) do
      {:ok, parsed} -> Broadway.Message.put_data(msg, parsed)
      {:error, _}   -> Broadway.Message.failed(msg, "invalid JSON")
    end
  end
end
```

## What NOT to Do

```elixir
# BAD: Ignoring the failed list — won't catch accidental failures
assert_receive {:ack, ^ref, [_msg], _}

# BAD: Not pinning the ref — could match any outstanding ack
assert_receive {:ack, _ref, successful, []}

# BAD: Using assert_received (no timeout) — races with pipeline processing
assert_received {:ack, ^ref, successful, failed}
```

## Timeout Considerations

`assert_receive` defaults to 100ms. If your handler does real work (DB calls,
HTTP requests) in tests, increase the timeout:

```elixir
assert_receive {:ack, ^ref, successful, failed}, 1_000
```

For pure in-memory processing, 100ms is typically sufficient.

## Detection

- Assertions using `_` for the failed list when testing happy paths
- Missing ref pinning: `{:ack, _ref, successful, failed}`
- `assert_received` instead of `assert_receive` in pipeline tests
- Tests that check side effects only (DB records, process state) and never assert on acks

## Further Reading

- [Broadway acknowledgment docs](https://hexdocs.pm/broadway/Broadway.html#module-acknowledgements)
- [Broadway.Message.failed/2](https://hexdocs.pm/broadway/Broadway.Message.html#failed/2)
