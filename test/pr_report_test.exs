defmodule TestCritic.PrReportTest do
  use ExUnit.Case, async: true

  alias TestCritic.PrReport

  @patch """
  diff --git a/test/a_test.exs b/test/a_test.exs
  --- a/test/a_test.exs
  +++ b/test/a_test.exs
  @@ -10,3 +10,4 @@ defmodule ATest do
     test "keeps" do
  +    Process.sleep(50)
  -    old()
  +    assert_raise RuntimeError, fn -> boom() end
     end
  @@ -40,2 +41,3 @@
     context
  +++ b/not/a/header
     more
  """

  @rules %{
    "ETC-CORE-005" => %{
      id: "ETC-CORE-005",
      severity: "critical",
      title: "Never use Process.sleep for synchronization",
      category: "core",
      path: "rules/core/no-process-sleep/RULE.md"
    },
    "ETC-ERR-001" => %{
      id: "ETC-ERR-001",
      severity: "warning",
      title: "Use 3-arity assert_raise with message matching",
      category: "errors",
      path: "rules/errors/assert-raise-with-message/RULE.md"
    },
    "ETC-ORG-001" => %{
      id: "ETC-ORG-001",
      severity: "style",
      title: "One module per file",
      category: "organization",
      path: "rules/organization/one-module/RULE.md"
    }
  }

  defp ctx(config \\ nil) do
    %{
      rules: @rules,
      added: PrReport.added_lines(@patch),
      config: PrReport.config(config),
      repo: "acme/app",
      sha: "0123456789abcdef",
      critic_ref: "main",
      files: 1,
      report_url: "https://example.test/report"
    }
  end

  defp finding(rule_id, line, extra \\ %{}) do
    Map.merge(
      %{
        "rule_id" => rule_id,
        "file" => "test/a_test.exs",
        "line" => line,
        "title" => "t",
        "why" => "w",
        "fix" => "f"
      },
      extra
    )
  end

  defp build(findings, config \\ nil), do: PrReport.build(%{"findings" => findings}, ctx(config))

  describe "added_lines/1" do
    test "numbers added lines by their place in the new file" do
      assert PrReport.added_lines(@patch) == %{"test/a_test.exs" => MapSet.new([11, 12, 42])}
    end
  end

  describe "rule_index/1" do
    test "reads every rule in the repo with a known severity" do
      index = PrReport.rule_index("rules")

      assert %{
               severity: "critical",
               category: "core",
               path: "rules/core/no-process-sleep/RULE.md"
             } =
               index["ETC-CORE-005"]

      assert Enum.all?(index, fn {_id, rule} ->
               rule.severity in ~w(critical warning recommendation style)
             end)

      assert map_size(index) == length(Path.wildcard("rules/*/*/RULE.md"))
    end
  end

  describe "build/2 vetting" do
    test "takes severity from the rule, not from the model" do
      report = build([finding("ETC-CORE-005", 11, %{"severity" => "style"})])

      assert [%{severity: "critical"}] = report.findings
    end

    test "drops a finding that cites an unknown rule" do
      report = build([finding("ETC-CORE-999", 11)])

      assert report.findings == []
      assert [%{drop: "cites a rule that does not exist"}] = report.dropped
    end

    test "drops a finding on a line or file the pull request did not add" do
      report =
        build([
          finding("ETC-CORE-005", 30),
          finding("ETC-CORE-005", 11, %{"file" => "test/other_test.exs"}),
          finding("ETC-CORE-005", nil)
        ])

      assert report.findings == []
      assert length(report.dropped) == 3
    end

    test "keeps a finding a few lines from an added line" do
      assert [%{line: 9}] = build([finding("ETC-CORE-005", 9)]).findings
    end

    test "applies .test_critic.yml" do
      findings = [
        finding("ETC-CORE-005", 11),
        finding("ETC-ERR-001", 12),
        finding("ETC-ORG-001", 42)
      ]

      assert ["ETC-CORE-005", "ETC-ERR-001"] =
               findings
               |> build("min_severity: warning\n")
               |> Map.fetch!(:findings)
               |> Enum.map(& &1.rule_id)

      assert ["ETC-ERR-001", "ETC-ORG-001"] =
               findings
               |> build("disabled_rules: [ETC-CORE-005]\n")
               |> Map.fetch!(:findings)
               |> Enum.map(& &1.rule_id)

      block =
        "disabled_categories:\n  - errors # too noisy\n  - organization\nmin_severity: style\n"

      assert ["ETC-CORE-005"] =
               findings |> build(block) |> Map.fetch!(:findings) |> Enum.map(& &1.rule_id)
    end
  end

  describe "score" do
    test "falls with warnings and is capped by critical findings" do
      warning = finding("ETC-ERR-001", 12)
      critical = finding("ETC-CORE-005", 11)

      assert build([finding("ETC-ORG-001", 42)]).score == 5
      assert build([warning, warning]).score == 4
      assert build([warning, warning, warning]).score == 3
      assert build([critical, warning]).score == 2
      assert build([critical, critical]).score == 1
    end
  end

  describe "what GitHub shows" do
    test "a clean review posts no comment and a passing check" do
      report = build([finding("ETC-ORG-001", 42)])

      assert report.comment == nil
      assert %{conclusion: "success", output: %{title: "5/5 · 1 style note"}} = report.check
      assert [%{annotation_level: "notice"}] = report.check.output.annotations
    end

    test "the comment lists critical and warning findings only, most severe first" do
      report =
        build([
          finding("ETC-ORG-001", 42),
          finding("ETC-ERR-001", 12),
          finding("ETC-CORE-005", 11)
        ])

      assert report.comment =~ "Elixir Test Critic: 2/5"
      assert report.comment =~ ~r/ETC-CORE-005.*ETC-ERR-001/s
      refute report.comment =~ "ETC-ORG-001"
      assert report.comment =~ "plus 1 style note"

      assert report.comment =~
               "<!-- elixir-test-critic:score=2 critical=1 warning=1 recommendation=0 style=1 -->"

      assert report.check.conclusion == "neutral"
      assert report.summary =~ "ETC-ORG-001"
    end

    test "the comment caps its list and points at the report for the rest" do
      report = build(List.duplicate(finding("ETC-ERR-001", 12), 8))

      assert report.comment |> String.split("\n- ") |> length() == 7
      assert report.comment =~ "and 2 more in the full report."
    end

    test "a reply with no findings list reports the review as unavailable" do
      report = PrReport.build(%{"error" => "knowledge base unavailable"}, ctx())

      assert report.score == nil
      assert report.comment == nil
      assert %{conclusion: "neutral", output: %{title: "Review unavailable"}} = report.check
    end
  end
end
