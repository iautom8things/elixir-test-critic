# EXPECTED: passes
# Demonstrates GOOD practice: testing handle_message/3 and handle_batch/4
# as plain functions WITHOUT starting a Broadway pipeline.
# Handler functions take structs and return structs — call them directly.
# In real Broadway, use Broadway.NoopAcknowledger.init() for the acknowledger field.
Mix.install([{:jason, "~> 1.4"}])

ExUnit.start(autorun: true)

# Simulated Broadway.Message struct — in real code: %Broadway.Message{}
# Real Broadway.Message has: data, metadata, acknowledger, batcher, batch_key, status
defmodule BwayHandlerGoodTest.Message do
  defstruct [:data, :metadata, :status, :acknowledger]

  def new(data, opts \\ []) do
    %__MODULE__{
      data: data,
      metadata: Keyword.get(opts, :metadata, %{}),
      status: :ok,
      # In real Broadway: Broadway.NoopAcknowledger.init()
      acknowledger: :noop
    }
  end

  # Simulates Broadway.Message.put_data/2
  def put_data(msg, data), do: %{msg | data: data}

  # Simulates Broadway.Message.failed/2
  def failed(msg, reason), do: %{msg | status: {:failed, reason}}
end

# The Broadway pipeline module under test — handler functions are plain functions
defmodule BwayHandlerGoodTest.EventPipeline do
  alias BwayHandlerGoodTest.Message

  # Real signature: handle_message(processor_name, message, context)
  def handle_message(_processor, %Message{data: data} = msg, _context) do
    case Jason.decode(data) do
      {:ok, parsed} ->
        enriched = Map.put(parsed, "processed_at", "2026-03-10")
        Message.put_data(msg, enriched)

      {:error, _} ->
        Message.failed(msg, "invalid JSON: #{inspect(data)}")
    end
  rescue
    _ -> Message.failed(msg, "unexpected error")
  end

  # Real signature: handle_batch(batcher, messages, batch_info, context)
  def handle_batch(_batcher, messages, _batch_info, _context) do
    # In a real pipeline: insert all messages to DB, mark each as ok or failed
    Enum.map(messages, fn msg ->
      if is_map(msg.data) and Map.has_key?(msg.data, "id") do
        msg  # successfully stored
      else
        Message.failed(msg, "missing required field: id")
      end
    end)
  end
end

defmodule BwayHandlerGoodTest do
  use ExUnit.Case, async: true

  alias BwayHandlerGoodTest.{EventPipeline, Message}

  # GOOD: No pipeline started — test handler functions directly
  describe "handle_message/3" do
    test "parses valid JSON and enriches with processed_at" do
      msg = Message.new(~s({"id": 1, "event": "purchase"}))

      result = EventPipeline.handle_message(:default, msg, %{})

      assert result.status == :ok
      assert result.data["id"] == 1
      assert result.data["event"] == "purchase"
      assert result.data["processed_at"] == "2026-03-10"
    end

    test "fails message on invalid JSON" do
      msg = Message.new("not-json-at-all")

      result = EventPipeline.handle_message(:default, msg, %{})

      assert {:failed, reason} = result.status
      assert reason =~ "invalid JSON"
    end

    test "fails message on malformed JSON structure" do
      msg = Message.new("{incomplete")

      result = EventPipeline.handle_message(:default, msg, %{})

      assert {:failed, _} = result.status
    end

    test "preserves metadata through processing" do
      msg = Message.new(~s({"id": 2}), metadata: %{source: "sqs", queue: "events"})

      result = EventPipeline.handle_message(:default, msg, %{})

      assert result.metadata == %{source: "sqs", queue: "events"}
    end
  end

  describe "handle_batch/4" do
    test "returns all messages when all have required fields" do
      messages =
        Enum.map(1..3, fn i ->
          msg = Message.new(~s({"id": #{i}}))
          Message.put_data(msg, %{"id" => i})
        end)

      results = EventPipeline.handle_batch(:db, messages, %{}, %{})

      assert length(results) == 3
      assert Enum.all?(results, fn m -> m.status == :ok end)
    end

    test "marks messages missing id field as failed" do
      good = Message.put_data(Message.new("x"), %{"id" => 1})
      bad  = Message.put_data(Message.new("y"), %{"event" => "purchase"})

      results = EventPipeline.handle_batch(:db, [good, bad], %{}, %{})

      [good_result, bad_result] = results
      assert good_result.status == :ok
      assert {:failed, reason} = bad_result.status
      assert reason =~ "id"
    end
  end
end
