defmodule TestCritic.TocGenerator do
  @moduledoc false

  alias TestCritic.RuleParser

  @category_descriptions %{
    "core" => "Fundamental ExUnit patterns every Elixir test should follow",
    "isolation" => "Ensuring tests don't interfere with each other",
    "errors" => "Testing error paths, exceptions, and edge cases",
    "otp" => "Testing GenServers, Supervisors, and OTP processes",
    "ecto" => "Database testing with Ecto and the sandbox",
    "mocking" => "When and how to use Mox, Bypass, and dependency injection",
    "phoenix" => "Testing Phoenix controllers, channels, and PubSub",
    "liveview" => "Testing LiveView components, events, and lifecycle",
    "oban" => "Testing Oban workers and job enqueueing",
    "property" => "Property-based testing with StreamData",
    "organization" => "Test suite structure and maintenance",
    "absinthe" => "Testing GraphQL schemas, resolvers, and subscriptions with Absinthe",
    "broadway" => "Testing Broadway pipelines, messages, and acknowledgments",
    "telemetry" => "Testing Telemetry event emission and handler behavior"
  }

  @category_order ~w(core isolation errors otp ecto mocking phoenix liveview oban property organization absinthe broadway telemetry)

  def generate(rules_dir \\ "rules", template_path \\ "templates/toc_template.md.eex", output_path \\ "toc/RULES_REFERENCE.md") do
    rules = RuleParser.discover_rules(rules_dir)

    categories =
      rules
      |> Enum.group_by(& &1.category)
      |> Enum.sort_by(fn {cat, _} -> Enum.find_index(@category_order, &(&1 == cat)) || 999 end)
      |> Enum.map(fn {category, rule_infos} ->
        parsed_rules =
          rule_infos
          |> Enum.map(fn %{path: path, slug: slug, category: cat} ->
            case RuleParser.parse_file(path) do
              {:ok, %{frontmatter: fm}} ->
                %{
                  id: Map.get(fm, "id", "???"),
                  title: Map.get(fm, "title", slug),
                  severity: Map.get(fm, "severity", "recommendation"),
                  summary: Map.get(fm, "summary", ""),
                  slug: slug,
                  category: cat,
                  applies_when: Map.get(fm, "applies_when", []),
                  does_not_apply_when: Map.get(fm, "does_not_apply_when", [])
                }

              _ ->
                nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        description = Map.get(@category_descriptions, category, "")

        index_path = Path.join([rules_dir, category, "_index.md"])

        description =
          if File.exists?(index_path) do
            index_path
            |> File.read!()
            |> extract_description()
            |> case do
              nil -> description
              desc -> desc
            end
          else
            description
          end

        %{name: category, description: description, rules: parsed_rules}
      end)

    template = File.read!(template_path)

    output = EEx.eval_string(template, assigns: %{categories: categories})

    File.mkdir_p!(Path.dirname(output_path))
    File.write!(output_path, output)

    {:ok, output_path}
  end

  defp extract_description(content) do
    content
    |> String.split("\n")
    |> Enum.drop_while(&(String.trim(&1) == "" or String.starts_with?(String.trim(&1), "#")))
    |> Enum.take_while(&(String.trim(&1) != ""))
    |> Enum.join(" ")
    |> String.trim()
    |> case do
      "" -> nil
      desc -> desc
    end
  end
end
