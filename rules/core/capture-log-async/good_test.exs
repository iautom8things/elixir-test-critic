# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule CaptureLogAsyncGoodTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  test "uses substring match on captured log" do
    log = capture_log(fn ->
      require Logger
      Logger.info("Processing request for user_id=42")
    end)

    # Correct: =~ checks for presence, robust to metadata and formatting
    assert log =~ "Processing request"
    assert log =~ "user_id=42"
  end

  test "refutes absence of error logs with substring check" do
    log = capture_log(fn ->
      require Logger
      Logger.info("All good")
    end)

    refute log =~ "[error]"
  end
end
