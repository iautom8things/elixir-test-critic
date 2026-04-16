# EXPECTED: passes
# BAD PRACTICE: A pipeline that hardcodes its producer with no mechanism for swapping.
# In a real app this means tests either skip the pipeline entirely, mock at the module
# level with Mox, or connect to real external infrastructure.
# This file demonstrates the antipattern — the pipeline is untestable in isolation.
Mix.install([])

ExUnit.start(autorun: true)

defmodule BwayDummyBadTest.SQSProducer do
  def type, do: :real
  def connect!, do: raise("Cannot connect to SQS without credentials!")
end

# BAD: Producer is hardcoded — no way to swap it out in tests
defmodule BwayDummyBadTest.Pipeline do
  @producer BwayDummyBadTest.SQSProducer

  def config do
    %{
      # Hardcoded — tests are stuck with the real SQS producer
      producer: @producer
    }
  end

  def start_link do
    config = config()
    # In a real app: Broadway.start_link would try to connect to SQS here
    # Tests would need to mock or use real AWS credentials
    {:ok, config}
  end
end

defmodule BwayDummyBadTest do
  use ExUnit.Case, async: true

  test "hardcoded pipeline always uses real producer — no swapping possible" do
    {:ok, config} = BwayDummyBadTest.Pipeline.start_link()

    # The pipeline is stuck with the real producer; tests can't inject DummyProducer
    assert config.producer == BwayDummyBadTest.SQSProducer
  end

  test "demonstrates the problem: attempting to connect would fail in CI" do
    config = BwayDummyBadTest.Pipeline.config()

    # In a real Broadway pipeline test, this would try to connect to real SQS:
    assert_raise RuntimeError, "Cannot connect to SQS without credentials!", fn ->
      config.producer.connect!()
    end
  end

  test "the fix is to accept producer as a parameter (see good_test.exs)" do
    # Without producer injection, you'd have to mock at the module level:
    # This is the antipattern — global state, no async, brittle
    hardcoded = BwayDummyBadTest.Pipeline.config()
    assert hardcoded.producer == BwayDummyBadTest.SQSProducer

    # Good version would be: MyPipeline.start_link(producer: Broadway.DummyProducer)
    :ok
  end
end
