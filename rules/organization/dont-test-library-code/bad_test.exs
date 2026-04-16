# EXPECTED: passes
# BAD PRACTICE: Tests that only verify library behaviour, not application logic.
# These tests give false confidence — if they fail, it's the library that's broken,
# not your code. They add noise and churn when libraries are upgraded.
Mix.install([])

ExUnit.start(autorun: true)

defmodule MyApp.DontTestLibBadTest do
  use ExUnit.Case, async: true

  # BAD: Testing that String.upcase/1 works — this is Elixir standard library.
  # If this fails, Elixir itself is broken. Your code is not tested here.
  test "BAD: String.upcase converts to uppercase" do
    assert String.upcase("hello") == "HELLO"
  end

  # BAD: Testing that Enum.sort/1 works — this is standard library.
  test "BAD: Enum.sort returns sorted list" do
    assert Enum.sort([3, 1, 2]) == [1, 2, 3]
  end

  # BAD: Testing that Map.put/3 works.
  test "BAD: Map.put adds a key to a map" do
    result = Map.put(%{}, :key, "value")
    assert result == %{key: "value"}
  end

  # BAD: Testing Jason.encode!/1 in isolation with no application logic.
  # (We use Jason.encode! stand-in here since Jason isn't installed)
  test "BAD: encoding a map produces expected string keys" do
    # This tests that Elixir's inspect works — not your code
    map = %{name: "Alice", age: 30}
    assert map.name == "Alice"
    assert map.age == 30
  end

  # All four tests above will never catch a bug in YOUR application code.
  # They only catch bugs in Elixir's standard library — which is maintained by
  # the core team and already extensively tested.
end
