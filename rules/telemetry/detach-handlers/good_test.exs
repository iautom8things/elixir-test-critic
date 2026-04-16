# EXPECTED: passes
Mix.install([:telemetry])

ExUnit.start(autorun: true)

defmodule TELE003.GoodTest do
  use ExUnit.Case, async: true

  test "attaches handler and registers on_exit cleanup" do
    test_pid = self()
    handler_id = "tele003-good-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:tele003, :job, :stop],
      fn _event, measurements, _meta, _cfg ->
        send(test_pid, {:job_done, measurements.elapsed})
      end,
      nil
    )

    # Cleanup registered immediately — runs even if the test fails
    on_exit(fn -> :telemetry.detach(handler_id) end)

    :telemetry.execute([:tele003, :job, :stop], %{elapsed: 55}, %{})

    assert_received {:job_done, 55}

    # Verify the handler is still attached mid-test (will be removed by on_exit)
    assert :telemetry.list_handlers([:tele003, :job, :stop])
           |> Enum.any?(fn h -> h.id == handler_id end)
  end

  test "prefers :telemetry_test helper which auto-cleans up" do
    # Using the official helper avoids manual on_exit entirely
    ref = :telemetry_test.attach_event_handlers(self(), [[:tele003, :task, :stop]])

    :telemetry.execute([:tele003, :task, :stop], %{duration: 12}, %{name: "sync"})

    assert_received {[:tele003, :task, :stop], ^ref, %{duration: 12}, %{name: "sync"}}
  end
end
