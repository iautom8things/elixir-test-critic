defmodule Mix.Tasks.GenerateToc do
  @shortdoc "Generates toc/RULES_REFERENCE.md from all rules"
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    {:ok, path} = TestCritic.TocGenerator.generate("rules", "templates/toc_template.md.eex", "toc/RULES_REFERENCE.md")
    Mix.shell().info("Generated #{path}")
  end
end
