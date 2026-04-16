defmodule Mix.Tasks.ValidateRules do
  @shortdoc "Validates all rule frontmatter and directory structure"
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    case TestCritic.Validator.validate_all("rules") do
      :ok ->
        rules = TestCritic.RuleParser.discover_rules("rules")
        Mix.shell().info("All #{length(rules)} rules valid.")

      {:error, errors} ->
        Mix.shell().error("Validation failed with #{length(errors)} error(s):\n")

        Enum.each(errors, fn error ->
          Mix.shell().error("  - #{error}")
        end)

        Mix.raise("Rule validation failed")
    end
  end
end
