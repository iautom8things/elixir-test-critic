defmodule TestCritic.Validator do
  @moduledoc false

  alias TestCritic.RuleParser

  @allowed_files ~w(RULE.md good_test.exs bad_test.exs support.ex)
  @valid_expected ~w(failure flaky passes)

  def validate_all(rules_dir \\ "rules") do
    rules = RuleParser.discover_rules(rules_dir)

    errors =
      rules
      |> Enum.flat_map(fn rule_info -> validate_rule(rule_info, rules_dir) end)

    cross_errors = validate_cross_rule(rules, rules_dir)

    all_errors = errors ++ cross_errors

    case all_errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_rule(%{path: path, category: category, slug: slug}, _rules_dir) do
    dir = Path.dirname(path)
    label = "#{category}/#{slug}"

    errors = []

    # Check directory contents
    errors = errors ++ validate_directory_contents(dir, label)

    # Check good_test.exs exists
    errors =
      if File.exists?(Path.join(dir, "good_test.exs")) do
        errors
      else
        [format_error(label, "missing good_test.exs") | errors]
      end

    # Check bad_test.exs EXPECTED comment if it exists
    bad_test_path = Path.join(dir, "bad_test.exs")

    errors =
      if File.exists?(bad_test_path) do
        errors ++ validate_expected_comment(bad_test_path, label)
      else
        errors
      end

    # Parse and validate frontmatter
    errors =
      case RuleParser.parse_file(path) do
        {:ok, %{frontmatter: fm}} ->
          errors ++ validate_frontmatter(fm, category, label)

        {:error, msg} ->
          [format_error(label, msg) | errors]
      end

    errors
  end

  defp validate_directory_contents(dir, label) do
    dir
    |> File.ls!()
    |> Enum.reject(&(&1 in @allowed_files))
    |> Enum.map(fn file ->
      format_error(label, "unexpected file: #{file}")
    end)
  end

  defp validate_expected_comment(path, label) do
    first_line =
      path
      |> File.stream!()
      |> Stream.reject(&(String.trim(&1) == ""))
      |> Enum.at(0, "")
      |> String.trim()

    case Regex.run(~r/^# EXPECTED:\s*(\w+)/, first_line) do
      [_, value] when value in @valid_expected ->
        []

      [_, value] ->
        [format_error(label, "bad_test.exs has invalid EXPECTED value: #{value} (must be one of: #{Enum.join(@valid_expected, ", ")})")]

      nil ->
        [format_error(label, "bad_test.exs exists but missing or invalid # EXPECTED: comment on first line")]
    end
  end

  defp validate_frontmatter(fm, expected_category, label) do
    errors = []

    # Required fields
    errors =
      Enum.reduce(RuleParser.required_fields(), errors, fn field, acc ->
        if Map.has_key?(fm, field) do
          acc
        else
          [format_error(label, "missing required frontmatter field: #{field}") | acc]
        end
      end)

    # Category match
    errors =
      case Map.get(fm, "category") do
        ^expected_category -> errors
        nil -> errors
        other -> [format_error(label, "category '#{other}' does not match directory '#{expected_category}'") | errors]
      end

    # Severity validity
    valid_severities = RuleParser.valid_severities()

    errors =
      case Map.get(fm, "severity") do
        nil -> errors
        sev -> if sev in valid_severities, do: errors, else: [format_error(label, "invalid severity: #{sev}") | errors]
      end

    # Critical severity requires does_not_apply_when
    errors =
      if Map.get(fm, "severity") == "critical" and not Map.has_key?(fm, "does_not_apply_when") do
        [format_error(label, "critical severity rules must have does_not_apply_when") | errors]
      else
        errors
      end

    # Principles validity
    valid_principles = RuleParser.valid_principles()

    errors =
      case Map.get(fm, "principles", []) do
        principles when is_list(principles) ->
          invalid = Enum.reject(principles, &(&1 in valid_principles))

          case invalid do
            [] -> errors
            bad -> [format_error(label, "invalid principles: #{Enum.join(bad, ", ")}") | errors]
          end

        _ ->
          errors
      end

    # Status validity
    valid_statuses = RuleParser.valid_statuses()

    errors =
      case Map.get(fm, "status") do
        nil -> errors
        status -> if status in valid_statuses, do: errors, else: [format_error(label, "invalid status: #{status}") | errors]
      end

    errors
  end

  defp validate_cross_rule(rules, _rules_dir) do
    # Parse all frontmatters
    parsed =
      rules
      |> Enum.map(fn %{path: path, category: cat, slug: slug} ->
        case RuleParser.parse_file(path) do
          {:ok, %{frontmatter: fm}} -> {cat, slug, fm}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    all_ids = parsed |> Enum.map(fn {_, _, fm} -> Map.get(fm, "id") end) |> Enum.reject(&is_nil/1)

    errors = []

    # ID uniqueness
    errors =
      all_ids
      |> Enum.frequencies()
      |> Enum.filter(fn {_id, count} -> count > 1 end)
      |> Enum.reduce(errors, fn {id, count}, acc ->
        ["Duplicate rule ID: #{id} (appears #{count} times)" | acc]
      end)

    # Bidirectional related_rules
    related_map =
      parsed
      |> Enum.map(fn {_cat, _slug, fm} ->
        {Map.get(fm, "id"), Map.get(fm, "related_rules", [])}
      end)
      |> Enum.reject(fn {id, _} -> is_nil(id) end)
      |> Map.new()

    errors =
      Enum.reduce(related_map, errors, fn {id, related}, acc ->
        Enum.reduce(related, acc, fn ref, inner_acc ->
          case Map.get(related_map, ref) do
            nil ->
              inner_acc

            back_refs ->
              if id in back_refs do
                inner_acc
              else
                ["#{id} lists #{ref} in related_rules but #{ref} does not list #{id} back" | inner_acc]
              end
          end
        end)
      end)

    # Conflicts_with validity
    errors =
      Enum.reduce(parsed, errors, fn {cat, slug, fm}, acc ->
        conflicts = Map.get(fm, "conflicts_with", [])
        label = "#{cat}/#{slug}"

        Enum.reduce(conflicts, acc, fn ref, inner_acc ->
          if ref in all_ids do
            inner_acc
          else
            [format_error(label, "conflicts_with references non-existent rule: #{ref}") | inner_acc]
          end
        end)
      end)

    errors
  end

  defp format_error(label, message) do
    "#{label}: #{message}"
  end
end
