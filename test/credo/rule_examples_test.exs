defmodule TestCritic.Credo.RuleExamplesTest do
  use Credo.Test.Case

  alias TestCritic.Credo.Check
  alias TestCritic.RuleParser

  setup_all do
    {:ok, _} = Application.ensure_all_started(:credo)
    :ok
  end

  test "each check agrees with its linked runnable examples" do
    modules =
      :test_critic
      |> Application.spec(:modules)
      |> Map.new(&{"credo:" <> inspect(&1), &1})

    for %{path: path, category: category, slug: slug} <- RuleParser.discover_rules("rules"),
        {:ok, rule} = RuleParser.parse_file(path),
        enforcement = rule.frontmatter["enforced_by"],
        enforcement do
      check = Map.fetch!(modules, enforcement)
      rule = Path.join(category, slug)
      bad_issues = rule |> example("bad", check) |> run_check(check)
      assert bad_issues != [], "expected #{inspect(check)} to report #{rule}/bad_test.exs"
      rule |> example("good", check) |> run_check(check) |> refute_issues()
    end
  end

  defp example(rule, kind, check) do
    filename = "#{rule}/#{kind}_test.exs"
    source = File.read!("rules/#{filename}")

    if check == Check.NondeterministicConfig do
      [_, config] = Regex.run(~r/config = """\n(.*?)\n\s+"""/s, source)
      to_source_file(config, "config/test.exs")
    else
      to_source_file(source, "test/#{filename}")
    end
  end
end
