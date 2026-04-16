defmodule Mix.Tasks.CheckRules do
  @shortdoc "Runs rule example scripts and verifies expected outcomes"
  @moduledoc false

  use Mix.Task

  def run(args) do
    rules = TestCritic.RuleParser.discover_rules("rules")

    rules =
      case args do
        [] ->
          rules

        [filter] ->
          case String.split(filter, "/", parts: 2) do
            [category, slug] ->
              Enum.filter(rules, fn r -> r.category == category and r.slug == slug end)

            [category] ->
              Enum.filter(rules, fn r -> r.category == category end)
          end

        _ ->
          Mix.raise("Usage: mix check_rules [<category> | <category>/<slug>]")
      end

    if rules == [] do
      Mix.shell().info("No rules matched the filter.")
      System.halt(0)
    end

    results = Enum.map(rules, &check_rule/1)

    passed = Enum.count(results, &(&1 == :pass))
    failed = Enum.count(results, &(&1 == :fail))

    Mix.shell().info("\nResults: #{length(results)} rules checked, #{passed} passed, #{failed} failed")

    if failed > 0, do: Mix.raise("#{failed} rule(s) failed")
  end

  defp check_rule(%{category: category, slug: slug}) do
    dir = Path.join(["rules", category, slug])
    label = "#{category}/#{slug}"
    Mix.shell().info("\nChecking #{label}...")

    good_result = run_script(Path.join(dir, "good_test.exs"), label, :good)

    bad_path = Path.join(dir, "bad_test.exs")

    bad_result =
      if File.exists?(bad_path) do
        expected = read_expected(bad_path)
        run_script(bad_path, label, {:bad, expected})
      else
        :pass
      end

    if good_result == :pass and bad_result == :pass, do: :pass, else: :fail
  end

  defp run_script(path, _label, mode) do
    file = Path.basename(path)

    {output, exit_code} =
      System.cmd("elixir", [Path.basename(path)],
        cd: Path.dirname(path),
        stderr_to_stdout: true,
        env: [{"MIX_QUIET", "1"}]
      )

    case mode do
      :good ->
        if exit_code == 0 do
          Mix.shell().info("  #{file}: PASS (exit 0)")
          :pass
        else
          Mix.shell().error("  #{file}: FAIL (expected exit 0, got exit #{exit_code})")
          Mix.shell().error("    #{String.slice(output, 0, 500)}")
          :fail
        end

      {:bad, expected} ->
        check_bad_result(file, exit_code, expected, output)
    end
  end

  defp check_bad_result(file, exit_code, expected, output) do
    case expected do
      "passes" ->
        if exit_code == 0 do
          Mix.shell().info("  #{file}: PASS (expected: passes, got: exit 0)")
          :pass
        else
          Mix.shell().error("  #{file}: FAIL (expected: passes, got: exit #{exit_code})")
          Mix.shell().error("    #{String.slice(output, 0, 500)}")
          :fail
        end

      "failure" ->
        if exit_code != 0 do
          Mix.shell().info("  #{file}: PASS (expected: failure, got: exit #{exit_code})")
          :pass
        else
          Mix.shell().error("  #{file}: FAIL (expected: failure, got: exit 0)")
          :fail
        end

      "flaky" ->
        Mix.shell().info("  #{file}: INFO (expected: flaky, got: exit #{exit_code})")
        :pass

      nil ->
        Mix.shell().error("  #{file}: FAIL (no EXPECTED comment found)")
        :fail
    end
  end

  defp read_expected(path) do
    path
    |> File.stream!()
    |> Stream.reject(&(String.trim(&1) == ""))
    |> Enum.at(0, "")
    |> String.trim()
    |> then(fn line ->
      case Regex.run(~r/^# EXPECTED:\s*(\w+)/, line) do
        [_, value] -> value
        nil -> nil
      end
    end)
  end
end
