# EXPECTED: passes
# BAD PRACTICE: In global mode the stub runs for any process, and it reports
# without saying whose call it was. Any process still alive from an earlier test
# that calls Engine.ask can satisfy the assertion with its own context.
Mix.install([{:mox, "~> 1.2"}])

ExUnit.start(autorun: true)

defmodule PinGlobalBad.Engine do
  @callback ask(context :: map()) :: :ok
end

Mox.defmock(PinGlobalBad.MockEngine, for: PinGlobalBad.Engine)

defmodule PinGlobalBad.Session do
  # Stands in for a session process the test cannot allow one by one.
  def ask_async(session_id, source) do
    spawn(fn -> PinGlobalBad.MockEngine.ask(%{session_id: session_id, source: source}) end)
    :ok
  end
end

defmodule PinGlobalBadTest do
  use ExUnit.Case, async: false
  import Mox

  setup :set_mox_global

  test "the turn carries its source" do
    test_pid = self()

    stub(PinGlobalBad.MockEngine, :ask, fn context ->
      send(test_pid, {:engine_called, context})
      :ok
    end)

    :ok = PinGlobalBad.Session.ask_async("session-1", :verify)

    # Matches the first :engine_called message from any process.
    assert_receive {:engine_called, %{source: :verify}}
  end
end
