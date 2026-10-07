# EXPECTED: passes
# BAD PRACTICE: The handler forwards every emission of the event name, whichever
# test caused it. Alone this passes; beside another async test that emits the
# same event, the refute_received fails at random and the assert_received can
# match a stranger's event.
Mix.install([{:telemetry, "~> 1.3"}])

ExUnit.start(autorun: true)

defmodule FilterOriginBad.Client do
  def call(tool) do
    :telemetry.execute([:filter_origin_bad, :call], %{count: 1}, %{tool: tool})
    {:error, :unavailable}
  end
end

defmodule FilterOriginBad.Forward do
  def handle(_event, measurements, metadata, test_pid),
    do: send(test_pid, {:call, measurements, metadata})
end

defmodule FilterOriginBadTest do
  use ExUnit.Case, async: true

  test "a failed call emits one event" do
    id = {__MODULE__, make_ref()}

    :ok =
      :telemetry.attach(id, [:filter_origin_bad, :call], &FilterOriginBad.Forward.handle/4, self())

    on_exit(fn -> :telemetry.detach(id) end)

    assert {:error, :unavailable} = FilterOriginBad.Client.call("whoami")
    assert_received {:call, _, %{tool: "whoami"}}
    refute_received {:call, _, _}
  end
end
