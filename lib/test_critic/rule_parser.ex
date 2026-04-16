defmodule TestCritic.RuleParser do
  @moduledoc false

  @required_fields ~w(id title category severity summary principles applies_when)
  @optional_fields ~w(does_not_apply_when tags related_rules sources conflicts_with status)
  @valid_severities ~w(critical warning recommendation style)
  @valid_statuses ~w(active draft deprecated)

  @valid_principles ~w(
    purity-separation contracts-first mock-as-noun integration-required
    async-default public-interface thin-processes honest-data
    boundary-testing assert-not-sleep
  )

  def required_fields, do: @required_fields
  def optional_fields, do: @optional_fields
  def valid_severities, do: @valid_severities
  def valid_statuses, do: @valid_statuses
  def valid_principles, do: @valid_principles

  @doc false
  def parse_file(path) do
    content = File.read!(path)
    parse(content, path)
  end

  @doc false
  def parse(content, source \\ "unknown") do
    case extract_frontmatter(content) do
      {:ok, yaml_string, body} ->
        case YamlElixir.read_from_string(yaml_string) do
          {:ok, frontmatter} ->
            {:ok, %{frontmatter: frontmatter, body: body, source: source}}

          {:error, reason} ->
            {:error, "Failed to parse YAML in #{source}: #{inspect(reason)}"}
        end

      :error ->
        {:error, "No YAML frontmatter found in #{source}"}
    end
  end

  defp extract_frontmatter(content) do
    case String.split(content, "---", parts: 3) do
      ["" | [yaml | [body | _]]] ->
        {:ok, String.trim(yaml), String.trim(body)}

      ["\n" | [yaml | [body | _]]] ->
        {:ok, String.trim(yaml), String.trim(body)}

      _ ->
        :error
    end
  end

  def discover_rules(rules_dir \\ "rules") do
    Path.wildcard(Path.join(rules_dir, "*/*/RULE.md"))
    |> Enum.map(fn path ->
      parts = Path.split(path)
      # rules/{category}/{slug}/RULE.md
      category = Enum.at(parts, -3)
      slug = Enum.at(parts, -2)
      %{path: path, category: category, slug: slug}
    end)
    |> Enum.sort_by(fn %{category: cat, slug: slug} -> {category_order(cat), slug} end)
  end

  @category_order ~w(core isolation errors otp ecto mocking phoenix liveview oban property organization absinthe broadway telemetry)
                  |> Enum.with_index()
                  |> Map.new()

  def category_order(category) do
    Map.get(@category_order, category, 999)
  end
end
