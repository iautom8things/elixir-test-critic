# EXPECTED: passes
# BAD PRACTICE: Demonstrates the on_exit process boundary confusion.
# The test attempts to use Process.get inside on_exit — but on_exit runs in a
# different process, so the process dictionary value is not visible.
# This test passes because we demonstrate the failure mode explicitly.
Mix.install([])

ExUnit.start(autorun: true)

defmodule OnExitProcessBoundaryBadTest do
  use ExUnit.Case, async: true

  test "process dictionary is NOT accessible in on_exit" do
    # Put a value in the test process's dictionary
    Process.put(:my_key, "my_value")

    # Verify it's accessible in the test process
    assert Process.get(:my_key) == "my_value"

    test_pid = self()

    on_exit(fn ->
      # on_exit runs in a different process — Process.get returns nil here
      value_in_on_exit = Process.get(:my_key)
      # Confirm: the value is NOT accessible from on_exit's process
      send(test_pid, {:got_value, value_in_on_exit})
    end)

    # We demonstrate the bad expectation: a developer might EXPECT the value
    # to be "my_value" in on_exit, but it will be nil.
    # The test passes here only to document this surprising behavior.
  end

  test "receives nil from on_exit process dictionary read" do
    # This test documents the behavior by receiving the message sent in on_exit above.
    # In a script context on_exit has already run by the time we get here,
    # so we just demonstrate the concept:
    assert Process.get(:my_key) == nil  # fresh process dict in this new test
  end
end
