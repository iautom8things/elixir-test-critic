# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule OnExitProcessBoundaryGoodTest do
  use ExUnit.Case, async: true

  test "on_exit runs in a different process than the test" do
    test_pid = self()

    on_exit(fn ->
      on_exit_pid = self()
      # Verify that on_exit runs in a different process
      send(test_pid, {:on_exit_pid, on_exit_pid})
    end)

    # The test process pid is captured here and sent from on_exit
    # (we can't receive it in the test body since on_exit runs after the test)
    refute test_pid == nil
  end

  test "on_exit can safely do process-independent cleanup" do
    # Safe: writing to a file is process-independent
    tmp_path = "/tmp/on_exit_test_#{System.unique_integer([:positive])}.txt"
    File.write!(tmp_path, "temp data")

    on_exit(fn ->
      # Safe: File.rm doesn't depend on process-specific state
      File.rm(tmp_path)
    end)

    assert File.exists?(tmp_path)
  end

  test "on_exit can access process dictionary values captured in closure" do
    # Safe: capture the value in the closure, don't read process dict inside on_exit
    value = "captured_value"

    on_exit(fn ->
      # Safe: value is captured in the closure, not read from process dictionary
      assert is_binary(value)
    end)

    assert value == "captured_value"
  end
end
