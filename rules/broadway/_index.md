# Broadway Rules

Rules for testing Broadway data ingestion pipelines.

Broadway is a concurrent, multi-stage data ingestion and data processing pipeline
framework for Elixir. It sits between an external message source (SQS, RabbitMQ,
Kafka, etc.) and your application logic. Testing Broadway pipelines requires
understanding two distinct concerns: **pipeline integration** (does the pipeline
wire up, route, and acknowledge messages correctly?) and **handler logic** (does my
transformation code do the right thing for given input?).

The most important insight for Broadway testing is that **handler callbacks are plain
functions**. `handle_message/3`, `handle_batch/4`, and `handle_failed/2` take structs
and return structs — no running pipeline required. The vast majority of Broadway
business logic tests should call these functions directly, without starting a pipeline
at all.

## Rules in this category

| ID | Rule | Severity |
|----|------|----------|
| [ETC-BWAY-001](dummy-producer/) | Use Broadway.DummyProducer in test config | recommendation |
| [ETC-BWAY-002](test-message-for-unit/) | Use test_message/3 for single-message unit tests | recommendation |
| [ETC-BWAY-003](ack-assertions/) | Assert on acknowledgment messages for correctness | recommendation |
| [ETC-BWAY-004](handler-isolation/) | Unit test handler functions in isolation | recommendation |

## Key concepts

**`Broadway.DummyProducer`** is Broadway's built-in test producer. It starts silently,
never emits messages on its own, and lets your test inject messages on demand via
`test_message/3` and `test_batch/3`. Configure your pipeline to accept its producer
module as a parameter so tests can swap it in without changing production code.

**`Broadway.test_message/3`** injects a single message into a running pipeline and
returns a `ref`. After processing, the pipeline sends `{:ack, ref, successful, failed}`
to your test process. Use `assert_receive {:ack, ^ref, successful, failed}` — always
pin the ref and always check both lists.

**Handler function isolation** is the most impactful Broadway testing technique. Since
`handle_message/3` and `handle_batch/4` are pure functions, construct
`Broadway.Message` structs with `Broadway.NoopAcknowledger.init()` as the acknowledger
and call the functions directly — no pipeline, no async: false, no setup overhead.

## The Testing Pyramid for Broadway

```
         [Integration]
        test_message/3 +
      assert_receive ack
    ────────────────────────
     [Unit: Handler Logic]
    handle_message/3 called
    directly with Message structs
    ─────────────────────────────────
    [Unit: Business Logic]
    Pure functions extracted from handlers
    tested with plain ExUnit
```

Most tests should live at the bottom two layers. Pipeline integration tests
(using `test_message/3`) are valuable but should be fewer in number.

## Setup

```elixir
# In your pipeline module — accept producer as an option for testability
def start_link(opts \\ []) do
  producer = Keyword.get(opts, :producer, MyApp.RealProducer)
  Broadway.start_link(__MODULE__,
    name: __MODULE__,
    producer: [module: {producer, []}, concurrency: 1],
    processors: [default: [concurrency: 2]]
  )
end
```

```elixir
# In your test for handler isolation
msg = %Broadway.Message{
  data: "payload",
  acknowledger: Broadway.NoopAcknowledger.init()
}
result = MyPipeline.handle_message(:default, msg, %{})
```

```elixir
# In your test for pipeline integration
{:ok, pid} = MyPipeline.start_link(producer: Broadway.DummyProducer)
ref = Broadway.test_message(pid, "payload")
assert_receive {:ack, ^ref, successful, failed}
```
