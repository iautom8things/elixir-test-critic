---
id: ETC-BWAY-002
title: "Use test_message/3 for single-message unit tests"
category: broadway
severity: recommendation
summary: >
  Broadway.test_message/3 injects a single message into a running pipeline and returns
  a unique reference. Use assert_receive {:ack, ^ref, successful, failed} to verify
  the message was processed correctly. This is the canonical pattern for per-message
  processing tests.
principles:
  - public-interface
applies_when:
  - "Testing that a single message is processed and acknowledged correctly"
  - "Verifying per-message transformation logic through the full pipeline"
  - "Testing error handling for individual messages"
does_not_apply_when:
  - "Testing batch processing logic — use test_batch/3 instead"
  - "Testing handler functions in isolation — use ETC-BWAY-004 instead"
  - "Sending multiple independent messages — call test_message/3 once per message"
related_rules:
  - ETC-BWAY-001
  - ETC-BWAY-003
  - ETC-CORE-004
---

# Use test_message/3 for single-message unit tests

`Broadway.test_message/3` is Broadway's helper for injecting a single message into a
pipeline during tests. It:

1. Wraps your data in a `Broadway.Message` struct
2. Sends it to the pipeline's DummyProducer
3. Returns a unique reference (`ref`)
4. Triggers an `:ack` message back to your test process when the pipeline finishes

Your test then uses `assert_receive {:ack, ^ref, successful, failed}` to verify the
outcome. The reference pins the assertion to exactly the message you sent, keeping
tests independent even when running async.

## Signature

```elixir
Broadway.test_message(server, data, opts \\ [])
# Returns: reference()
```

`opts` accepts:
- `metadata:` — extra metadata map merged into the message
- `batch_mode:` — `:bulk` (default) or `:flush`

## Good

```elixir
defmodule MyApp.PipelineTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, pid} = MyApp.Pipeline.start_link(producer: Broadway.DummyProducer)
    on_exit(fn -> Broadway.stop(pid) end)
    {:ok, pid: pid}
  end

  test "successful message is acked", %{pid: pid} do
    ref = Broadway.test_message(pid, "valid-payload")

    assert_receive {:ack, ^ref, successful, failed}
    assert length(successful) == 1
    assert failed == []
  end

  test "malformed message is failed", %{pid: pid} do
    ref = Broadway.test_message(pid, "bad-payload")

    assert_receive {:ack, ^ref, successful, failed}
    assert successful == []
    assert length(failed) == 1
  end
end
```

## Bad

```elixir
defmodule MyApp.PipelineTest do
  use ExUnit.Case, async: false

  test "processes message" do
    # BAD: sleeping to wait for pipeline processing — timing-dependent and fragile
    {:ok, pid} = MyApp.Pipeline.start_link(producer: Broadway.DummyProducer)
    Broadway.test_message(pid, "hello")
    Process.sleep(500)

    # No way to pin this to our specific message — could be any ack
    assert_received {:ack, _ref, _successful, _failed}
  end
end
```

## Checking Message Data in the Ack

The `successful` and `failed` lists contain `Broadway.Message` structs. You can
inspect the processed data:

```elixir
assert_receive {:ack, ^ref, [msg], []}
assert msg.data == "transformed-value"
```

## Multiple Independent Messages

Send each with its own `test_message/3` call and match on each ref separately:

```elixir
ref1 = Broadway.test_message(pid, "first")
ref2 = Broadway.test_message(pid, "second")

assert_receive {:ack, ^ref1, [_], []}
assert_receive {:ack, ^ref2, [_], []}
```

## Detection

- Tests that `Process.sleep/1` after sending messages, hoping the pipeline finishes
- Tests that use `assert_received` (past tense, no timeout) without the ref pinned
- Tests that call `:sys.get_state` on the pipeline to inspect results

## Further Reading

- [Broadway.test_message/3](https://hexdocs.pm/broadway/Broadway.html#test_message/3)
- [Broadway.test_batch/3](https://hexdocs.pm/broadway/Broadway.html#test_batch/3)
