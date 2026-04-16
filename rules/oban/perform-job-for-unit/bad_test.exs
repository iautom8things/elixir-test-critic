# EXPECTED: passes
# BAD PRACTICE: Calling perform/1 directly with atom-keyed args.
# The tests pass here, but the worker would FAIL in production because
# Oban passes string-keyed maps (after JSON serialisation/deserialisation).
# This file demonstrates the hidden bug — tests green, production red.
Mix.install([])

ExUnit.start(autorun: true)

defmodule MyApp.EmailWorkerBadTest.Worker do
  # BUG: pattern-matches on atom keys — works in tests, breaks in production
  def perform(%{args: %{user_id: user_id, template: template}}) do
    {:ok, "sent #{template} to user #{user_id}"}
  end
end

defmodule MyApp.EmailWorkerBadTest do
  use ExUnit.Case, async: true

  alias MyApp.EmailWorkerBadTest.Worker

  test "sends email — test passes but production will fail" do
    # BAD: manually constructing with atom keys, bypassing Oban's key coercion
    job = %{args: %{user_id: 42, template: "welcome"}}
    assert {:ok, "sent welcome to user 42"} = Worker.perform(job)
  end

  test "demonstrates the production failure — string keys cause no_match" do
    # This is what Oban actually passes — and our worker can't handle it
    job = %{args: %{"user_id" => 42, "template" => "welcome"}}

    assert_raise FunctionClauseError, fn ->
      Worker.perform(job)
    end
  end
end
