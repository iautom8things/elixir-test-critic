# EXPECTED: passes
Mix.install([:mox])

ExUnit.start(autorun: true)

# Step 1: Define the behaviour (the contract)
defmodule MOCK001.NotifierBehaviour do
  @callback notify(recipient :: String.t(), message :: String.t()) ::
              :ok | {:error, term()}
end

# Step 2: Real implementation adopts the behaviour
defmodule MOCK001.LogNotifier do
  @behaviour MOCK001.NotifierBehaviour

  @impl true
  def notify(recipient, message) do
    # In production: sends a real notification
    _ = {recipient, message}
    :ok
  end
end

# Step 3: Create mock backed by the behaviour
Mox.defmock(MOCK001.NotifierMock, for: MOCK001.NotifierBehaviour)

# The module under test depends on the behaviour, not a specific implementation
defmodule MOCK001.AlertService do
  def send_alert(notifier, recipient, message) do
    notifier.notify(recipient, message)
  end
end

defmodule MOCK001.BehaviourBeforeMockGoodTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  test "AlertService delegates to the notifier behaviour" do
    MOCK001.NotifierMock
    |> expect(:notify, fn "ops@example.com", "System is down" -> :ok end)

    result = MOCK001.AlertService.send_alert(
      MOCK001.NotifierMock,
      "ops@example.com",
      "System is down"
    )

    assert result == :ok
  end

  test "behaviour guarantees the real implementation has the same callback" do
    # Verify the real implementation satisfies the behaviour at compile time
    # (Elixir would warn/error at compile if @impl is wrong)
    assert function_exported?(MOCK001.LogNotifier, :notify, 2)
    assert function_exported?(MOCK001.NotifierMock, :notify, 2)
  end
end
