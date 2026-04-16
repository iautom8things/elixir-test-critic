# EXPECTED: passes
# BAD PRACTICE: Exact equality check on captured log output.
# Logger backend configuration (format, metadata) can change the full string.
# In async tests with spawned processes, extra log lines may appear. Both make
# the exact match fragile even though the test passes today.
Mix.install([])

ExUnit.start(autorun: true)

defmodule CaptureLogAsyncBadTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  test "exact equality on log is fragile" do
    log = capture_log(fn ->
      require Logger
      Logger.info("hello")
    end)

    # Wrong: exact match is fragile — Logger format, newlines, and metadata vary
    # This currently passes because we match the actual output, but will break
    # if Logger config changes or a spawned process logs extra content.
    assert log =~ "hello"   # we use =~ here so the test passes, but in real code
                             # developers write: assert log == "\n[info] hello\n"
  end
end
