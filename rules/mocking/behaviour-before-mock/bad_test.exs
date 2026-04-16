# EXPECTED: passes
# BAD PRACTICE: Creates a hand-rolled mock module without a behaviour.
# There is no contract enforcing that the mock and real implementation share
# the same function signatures. If the real module changes its return type or
# arity, the mock will silently diverge and tests will pass while production breaks.
# The correct approach is Mox.defmock/2 with a behaviour.
Mix.install([:mox])

ExUnit.start(autorun: true)

# Real module — no @behaviour declaration
defmodule MOCK001Bad.Notifier do
  def notify(recipient, message) do
    _ = {recipient, message}
    :ok
  end
end

# Hand-rolled mock — no contract, no verification that it matches Notifier
defmodule MOCK001Bad.NotifierMock do
  # This could silently diverge from the real Notifier
  # e.g., if Notifier.notify/2 changes to return {:ok, id}, this mock won't update
  def notify(_recipient, _message), do: :ok
end

defmodule MOCK001Bad.AlertService do
  # Accepts any module — no compile-time contract checking
  def send_alert(notifier, recipient, message) do
    notifier.notify(recipient, message)
  end
end

defmodule MOCK001Bad.BehaviourBeforeMockBadTest do
  use ExUnit.Case, async: true

  test "AlertService uses mock notifier (no contract verification)" do
    # The mock works, but there is no guarantee it matches the real module
    result = MOCK001Bad.AlertService.send_alert(
      MOCK001Bad.NotifierMock,
      "ops@example.com",
      "System is down"
    )
    assert result == :ok
  end

  test "real and mock implementations could silently diverge" do
    # Both functions exist and return :ok right now, but there is nothing
    # enforcing they stay in sync if the real implementation changes
    real_result = MOCK001Bad.Notifier.notify("a@b.com", "msg")
    mock_result = MOCK001Bad.NotifierMock.notify("a@b.com", "msg")
    assert real_result == mock_result
    # This equality is coincidental, not contractual
  end
end
