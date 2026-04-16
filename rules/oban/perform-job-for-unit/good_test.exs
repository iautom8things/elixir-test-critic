# EXPECTED: passes
# Demonstrates the CONCEPT of perform_job/3 without requiring Oban/Postgres.
# In a real app: use Oban.Testing.perform_job/3 which handles arg coercion.
# This test shows WHY string-keyed args matter and how to write workers correctly.
Mix.install([])

ExUnit.start(autorun: true)

# In real Oban workers, perform/1 always receives string-keyed args because
# args are serialised to JSON and back. We model that behaviour here.
defmodule MyApp.EmailWorkerGoodTest.Worker do
  # Simulate what Oban does: convert atom keys to string keys before calling perform/1
  def perform_job(args) when is_map(args) do
    string_keyed = Map.new(args, fn {k, v} -> {to_string(k), v} end)
    perform(%{args: string_keyed})
  end

  # Worker correctly pattern-matches on string keys — works at runtime
  def perform(%{args: %{"user_id" => user_id, "template" => template}}) do
    if user_id > 0 do
      # Would send email here
      {:ok, "sent #{template} to user #{user_id}"}
    else
      {:discard, "user not found"}
    end
  end
end

defmodule MyApp.EmailWorkerGoodTest do
  use ExUnit.Case, async: true

  alias MyApp.EmailWorkerGoodTest.Worker

  test "perform_job/1 coerces atom keys to string keys before calling perform/1" do
    # We pass atom-keyed args (as the caller would in tests)
    # perform_job/1 converts them, matching what Oban does
    assert {:ok, "sent welcome to user 42"} =
             Worker.perform_job(%{user_id: 42, template: "welcome"})
  end

  test "worker handles unknown user with discard" do
    assert {:discard, "user not found"} =
             Worker.perform_job(%{user_id: 0, template: "welcome"})
  end

  test "worker receives string keys in perform/1 — the production reality" do
    # This is what Oban actually passes to perform/1 after deserialising from DB
    assert {:ok, _} =
             Worker.perform(%{args: %{"user_id" => 99, "template" => "reset"}})
  end
end
