defmodule Mix.Tasks.Shampoo.GenerateToc do
  @shortdoc "Generates toc/RULES_REFERENCE.md from all rules"
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, path} = Shampoo.TocGenerator.generate()
    Mix.shell().info("Generated #{path}")
  end
end
