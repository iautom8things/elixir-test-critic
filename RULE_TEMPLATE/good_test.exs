# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

# Define any modules needed for the test inline here.
# If the module is shared with bad_test.exs and > 15 lines,
# move it to support.ex and use: Code.require_file("support.ex", __DIR__)

defmodule ExampleTest do
  use ExUnit.Case

  test "demonstrates the recommended pattern" do
    # Replace with actual test code
    assert true
  end
end
