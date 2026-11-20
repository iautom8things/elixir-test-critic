# EXPECTED: passes
Mix.install([])

ExUnit.start(autorun: true)

defmodule BuildTimeConfigGoodTest do
  use ExUnit.Case, async: true

  test "reads the build-time configuration twice" do
    config = """
    import Config
    config :widget, generation: 1
    """

    first_read = Config.Reader.eval!("config/test.exs", config)
    second_read = Config.Reader.eval!("config/test.exs", config)
    assert first_read == second_read
  end
end
