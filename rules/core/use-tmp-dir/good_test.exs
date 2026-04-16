# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule UseTmpDirGoodTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "writes and reads a file in isolated tmp dir", %{tmp_dir: dir} do
    path = Path.join(dir, "output.txt")
    File.write!(path, "hello world")
    assert File.read!(path) == "hello world"
    # No cleanup needed — ExUnit removes the tmp_dir after the test
  end

  @tag :tmp_dir
  test "two tests get different directories", %{tmp_dir: dir} do
    # Each test gets its own unique directory
    assert File.dir?(dir)
    path = Path.join(dir, "other.txt")
    File.write!(path, "test isolation")
    assert File.exists?(path)
  end
end
