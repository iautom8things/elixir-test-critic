# EXPECTED: passes
# BAD PRACTICE: Hardcoded /tmp path shared across tests. In async mode, two tests
# writing to the same path race each other. The on_exit cleanup is manual boilerplate
# that is forgotten when tests fail midway through.
Mix.install([])

ExUnit.start(autorun: true)

defmodule UseTmpDirBadTest do
  use ExUnit.Case, async: true

  test "writes and reads a file to hardcoded path" do
    # Wrong: hardcoded path — conflicts with any other test using the same path
    path = "/tmp/elixir_test_critic_bad_example.txt"
    on_exit(fn -> File.rm(path) end)

    File.write!(path, "hello world")
    assert File.read!(path) == "hello world"
  end
end
