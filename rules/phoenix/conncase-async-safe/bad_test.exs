# EXPECTED: passes
# BAD PRACTICE: ConnCase module missing async: true. Tests run sequentially
# even though the SQL sandbox fully supports concurrent execution. This
# unnecessarily slows the test suite.
Mix.install([])

ExUnit.start(autorun: true)

defmodule ConnCaseAsyncBadTest do
  # In a real app this would be: use MyAppWeb.ConnCase
  # Without async: true, ExUnit defaults to async: false — sequential execution.
  use ExUnit.Case   # no async: true — sequential by default

  test "runs sequentially even though it could run concurrently" do
    # This test has no shared global state. It does not call Application.put_env,
    # does not use a singleton process, does not need exclusive DB access.
    # Yet it runs sequentially because async: true was omitted.
    result = String.upcase("hello")
    assert result == "HELLO"
  end

  test "another sequential test with no reason to be sequential" do
    # ConnCase with Ecto sandbox supports async. Omitting async: true
    # forces serialisation of what could be parallel work.
    assert 1 + 1 == 2
  end

  test "hidden coupling risk: sequential tests can share global state undetected" do
    # When tests run sequentially, two tests that both mutate Application env
    # may pass because they run in order. Switch to async and the race condition
    # surfaces. Staying sequential hides the problem.
    assert Process.get(:some_key) == nil
  end
end
