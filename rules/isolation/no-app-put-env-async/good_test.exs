# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule NoAppPutEnvAsyncFeature do
  # Good design: accepts configuration as a parameter instead of reading global env
  def enabled?(opts \\ []) do
    Keyword.get(opts, :feature_enabled, Application.get_env(:no_app_put_env_app, :feature_enabled, false))
  end
end

defmodule NoAppPutEnvAsyncGoodTest do
  use ExUnit.Case, async: true

  test "feature is enabled when option is passed" do
    # No global state mutation — passes the flag as a parameter
    assert NoAppPutEnvAsyncFeature.enabled?(feature_enabled: true)
  end

  test "feature is disabled by default" do
    refute NoAppPutEnvAsyncFeature.enabled?()
  end
end
