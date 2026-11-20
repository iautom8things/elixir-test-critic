# EXPECTED: passes
# BAD PRACTICE: Generate a different config value on each read.
Mix.install([])

ExUnit.start(autorun: true)

defmodule BuildTimeConfigBadTest do
  use ExUnit.Case, async: true

  test "reads the build-time configuration twice" do
    config = """
    import Config
    config :widget, generation: System.unique_integer([:positive, :monotonic])
    """

    assert Config.Reader.eval!("config/test.exs", config) !=
             Config.Reader.eval!("config/test.exs", config)
  end
end
