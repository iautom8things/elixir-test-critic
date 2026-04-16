# EXPECTED: passes
# Demonstrates GOOD practice: swapping the producer module for tests.
# In real Broadway: Broadway.DummyProducer is passed as the producer in test config.
# Here we simulate the concept — a pipeline that accepts its producer as a parameter,
# vs one that hardcodes it. The DummyProducer pattern means NO messages arrive unless
# the test explicitly injects them.
Mix.install([])

ExUnit.start(autorun: true)

# Simulated "producer" modules — in real Broadway these implement GenStage
defmodule BwayDummyGoodTest.SQSProducer do
  # Real producer: pulls from SQS — not usable in tests without AWS
  def type, do: :real
end

defmodule BwayDummyGoodTest.DummyProducer do
  # Test producer: emits nothing on its own; messages injected by test_message/3
  def type, do: :dummy
end

# Pipeline that accepts its producer module as a parameter — testable!
defmodule BwayDummyGoodTest.Pipeline do
  def config(opts \\ []) do
    producer = Keyword.get(opts, :producer, BwayDummyGoodTest.SQSProducer)

    %{
      producer: producer,
      # In real Broadway: Broadway.start_link(__MODULE__, name: ..., producer: ...)
    }
  end

  def start_link(opts \\ []) do
    config = config(opts)
    # In production: Broadway.start_link(__MODULE__, broadway_opts)
    # Here we just return the config for demonstration
    {:ok, config}
  end
end

defmodule BwayDummyGoodTest do
  use ExUnit.Case, async: true

  test "pipeline accepts DummyProducer in tests — no external dependencies" do
    {:ok, config} = BwayDummyGoodTest.Pipeline.start_link(producer: BwayDummyGoodTest.DummyProducer)

    # The pipeline is configured with DummyProducer — no SQS connection required
    assert config.producer == BwayDummyGoodTest.DummyProducer
    assert config.producer.type() == :dummy
  end

  test "production pipeline uses real producer" do
    {:ok, config} = BwayDummyGoodTest.Pipeline.start_link()

    assert config.producer == BwayDummyGoodTest.SQSProducer
    assert config.producer.type() == :real
  end

  test "DummyProducer is distinguishable from real producer" do
    # Key property: in tests we can verify we have the dummy, not the real producer
    test_config = BwayDummyGoodTest.Pipeline.config(producer: BwayDummyGoodTest.DummyProducer)
    prod_config = BwayDummyGoodTest.Pipeline.config()

    refute test_config.producer == prod_config.producer
  end

  test "pipeline can be started with different producers without code changes" do
    # The same pipeline module works with any producer — swap via config/opts
    configs =
      [BwayDummyGoodTest.DummyProducer, BwayDummyGoodTest.SQSProducer]
      |> Enum.map(fn p -> BwayDummyGoodTest.Pipeline.config(producer: p) end)

    [dummy_cfg, sqs_cfg] = configs
    assert dummy_cfg.producer == BwayDummyGoodTest.DummyProducer
    assert sqs_cfg.producer == BwayDummyGoodTest.SQSProducer
  end
end
