# EXPECTED: passes
# BAD PRACTICE: Describe what's wrong with this approach.
Mix.install([])

ExUnit.start(autorun: true)

defmodule BadExampleTest do
  use ExUnit.Case

  test "demonstrates the anti-pattern" do
    # Replace with actual test code showing the bad practice
    assert true
  end
end
