# EXPECTED: passes
# BAD PRACTICE: Application.put_env in an async test. In a real suite with many
# async tests, this mutation is immediately visible to all other concurrent tests.
# The test passes here only because it runs alone; in a full async suite it
# would cause intermittent failures in unrelated tests.
Mix.install([])

ExUnit.start(autorun: true)

defmodule NoAppPutEnvAsyncBadFeature do
  def enabled? do
    Application.get_env(:no_app_put_env_bad_app, :feature_enabled, false)
  end
end

defmodule NoAppPutEnvAsyncBadTest do
  use ExUnit.Case, async: true   # async: true + Application.put_env = race condition

  test "feature is enabled when flag is set" do
    # Wrong: mutates global VM-wide state while other async tests may be reading it
    Application.put_env(:no_app_put_env_bad_app, :feature_enabled, true)
    assert NoAppPutEnvAsyncBadFeature.enabled?()
    # Cleanup also racy — other tests may have already read the wrong value
    Application.delete_env(:no_app_put_env_bad_app, :feature_enabled)
  end
end
