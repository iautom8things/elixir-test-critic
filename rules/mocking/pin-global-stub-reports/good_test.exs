# EXPECTED: passes
Mix.install([{:mox, "~> 1.2"}])

ExUnit.start(autorun: true)

defmodule PinGlobalGood.Engine do
  @callback ask(context :: map()) :: :ok
end

Mox.defmock(PinGlobalGood.MockEngine, for: PinGlobalGood.Engine)

defmodule PinGlobalGood.Session do
  # Stands in for a session process the test cannot allow one by one.
  def ask_async(session_id, source) do
    spawn(fn -> PinGlobalGood.MockEngine.ask(%{session_id: session_id, source: source}) end)
    :ok
  end
end

defmodule PinGlobalGoodTest do
  use ExUnit.Case, async: false
  import Mox

  setup :set_mox_global

  test "the turn carries its source, and a stray caller cannot answer for it" do
    test_pid = self()
    sid = "session-#{System.unique_integer([:positive])}"

    stub(PinGlobalGood.MockEngine, :ask, fn context ->
      send(test_pid, {:engine_called, context.session_id, context})
      :ok
    end)

    # A process left over from an earlier test reaches the same global stub
    # first, with the same source.
    :ok = PinGlobalGood.Session.ask_async("stray-session", :verify)
    assert_receive {:engine_called, "stray-session", _stray}

    :ok = PinGlobalGood.Session.ask_async(sid, :verify)

    # The pin takes only this test's call.
    assert_receive {:engine_called, ^sid, %{source: :verify}}
  end
end
