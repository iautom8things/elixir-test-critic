# EXPECTED: passes
Mix.install([{:telemetry, "~> 1.3"}])

ExUnit.start(autorun: true, max_cases: 2)

defmodule FilterOriginGood.Client do
  def call(tool) do
    :telemetry.execute([:filter_origin_good, :call], %{count: 1}, %{tool: tool})
    {:error, :unavailable}
  end
end

defmodule FilterOriginGood.TelemetryHelpers do
  # Forwards an event only when the emitting process is the test or carries it
  # in $callers. Handlers run inline in the emitting process, so self() here is
  # the origin.
  def attach_owned(events, to_message) do
    test_pid = self()
    id = {__MODULE__, test_pid, System.unique_integer([:positive])}
    config = %{test_pid: test_pid, to_message: to_message}
    :ok = :telemetry.attach_many(id, events, &__MODULE__.forward_owned/4, config)
    ExUnit.Callbacks.on_exit(fn -> :telemetry.detach(id) end)
    id
  end

  def forward_owned(event, measurements, metadata, %{test_pid: test_pid, to_message: to_message}) do
    if self() == test_pid or test_pid in Process.get(:"$callers", []) do
      send(test_pid, to_message.(event, measurements, metadata))
    end
  end
end

defmodule FilterOriginGoodNoisyNeighbourTest do
  # Another async module emitting the same event while the test below runs.
  use ExUnit.Case, async: true

  test "a neighbour calls the client many times" do
    for _ <- 1..2_000, do: FilterOriginGood.Client.call("list_instances")
  end
end

defmodule FilterOriginGoodTest do
  use ExUnit.Case, async: true
  import FilterOriginGood.TelemetryHelpers

  test "a failed call emits one event, and the neighbour's events never arrive" do
    attach_owned([[:filter_origin_good, :call]], fn _event, measurements, metadata ->
      {:call, measurements, metadata}
    end)

    for _ <- 1..200 do
      assert {:error, :unavailable} = FilterOriginGood.Client.call("whoami")
      assert_received {:call, _, %{tool: "whoami"}}
      refute_received {:call, _, _}
    end
  end

  test "an event emitted from a Task the test started still arrives" do
    attach_owned([[:filter_origin_good, :call]], fn _event, _measurements, metadata ->
      {:call, metadata}
    end)

    Task.await(Task.async(fn -> FilterOriginGood.Client.call("from_task") end))
    assert_received {:call, %{tool: "from_task"}}
  end
end
