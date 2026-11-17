defmodule TestCritic.PrReport do
  @moduledoc """
  Turns a model's review of a pull request into what GitHub shows.

  The model proposes findings. This module decides what is reported: it takes
  each finding's severity and title from the rule file, drops findings that
  cite an unknown rule or a line the pull request did not add, applies
  `.test_critic.yml`, and computes the score. The model never sets the score.
  """

  @severities ~w(critical warning recommendation style)
  @marker "<!-- elixir-test-critic -->"
  @check_name "Elixir Test Critic"
  @rules_repo "https://github.com/iautom8things/elixir-test-critic"

  # A finding may sit this many lines from an added line and still count as
  # part of the change, e.g. the `use ... async: false` above an added test.
  @line_slack 3
  @comment_limit 6
  @annotation_limit 50

  def marker, do: @marker
  def check_name, do: @check_name

  @doc """
  Builds the report.

  `review` is the decoded model reply. `ctx` needs `:rules` (from
  `rule_index/1`), `:added` (from `added_lines/1`) and `:config` (from
  `config/1`), plus `:repo`, `:sha`, `:critic_ref` and `:files` for links.
  """
  def build(%{"findings" => findings} = review, ctx) when is_list(findings) do
    {kept, dropped} = vet(findings, ctx)
    counts = counts(kept)
    score = score(counts)

    report = %{
      score: score,
      counts: counts,
      findings: kept,
      dropped: dropped,
      strengths: review |> Map.get("strengths", []) |> Enum.take(3),
      files: ctx.files
    }

    Map.merge(report, %{
      comment: comment(report, ctx),
      summary: summary(report, ctx),
      check: check(report, ctx)
    })
  end

  def build(_review, ctx), do: unavailable(ctx)

  @doc "The report for a run where the model gave no usable review."
  def unavailable(ctx) do
    text = "The review did not complete, so there is no score for this commit."

    %{
      score: nil,
      counts: counts([]),
      findings: [],
      dropped: [],
      strengths: [],
      files: ctx.files,
      comment: nil,
      summary: text,
      check: %{
        name: @check_name,
        head_sha: ctx.sha,
        status: "completed",
        conclusion: "neutral",
        output: %{title: "Review unavailable", summary: text, annotations: []}
      }
    }
  end

  @doc """
  Scores the changed tests from 1 to 5.

  5 means no critical or warning finding. Warnings cost one point, or two when
  there are three or more. One critical finding caps the score at 2, and two
  or more make it 1. Recommendations and style notes never move the score.
  """
  def score(%{"critical" => 0, "warning" => 0}), do: 5
  def score(%{"critical" => 0, "warning" => w}) when w <= 2, do: 4
  def score(%{"critical" => 0}), do: 3
  def score(%{"critical" => 1}), do: 2
  def score(_counts), do: 1

  @doc "Maps each rule ID to its severity, title, category and repo path."
  def rule_index(rules_dir) do
    for path <- Path.wildcard(Path.join(rules_dir, "*/*/RULE.md")),
        front = front_matter(File.read!(path)),
        id = field(front, "id"),
        into: %{} do
      {id,
       %{
         id: id,
         severity: field(front, "severity"),
         title: field(front, "title"),
         category: field(front, "category"),
         path: Path.join("rules", Path.relative_to(path, rules_dir))
       }}
    end
  end

  @doc "Maps each file in a unified diff to the set of line numbers it adds."
  def added_lines(patch) do
    patch
    |> String.split("\n")
    |> Enum.reduce({%{}, nil, 0, nil}, &added_line/2)
    |> elem(0)
  end

  defp added_line("+++ b/" <> file, {acc, _file, _line, "--- " <> _}),
    do: {Map.put_new(acc, file, MapSet.new()), file, 0, nil}

  defp added_line("@@ " <> _ = hunk, {acc, file, _line, _prev}) do
    [_, start] = Regex.run(~r/^@@ -\S+ \+(\d+)/, hunk)
    {acc, file, String.to_integer(start), hunk}
  end

  defp added_line("+" <> _ = row, {acc, file, line, _prev}) when is_binary(file),
    do: {Map.update!(acc, file, &MapSet.put(&1, line)), file, line + 1, row}

  defp added_line("-" <> _ = row, {acc, file, line, _prev}), do: {acc, file, line, row}
  defp added_line("\\" <> _ = row, {acc, file, line, _prev}), do: {acc, file, line, row}
  defp added_line(row, {acc, file, line, _prev}), do: {acc, file, line + 1, row}

  @doc """
  Reads the three `.test_critic.yml` keys. A missing or empty file reports
  everything.
  """
  def config(nil), do: %{min_severity: "style", disabled_rules: [], disabled_categories: []}

  def config(yaml) do
    min = Regex.run(~r/^min_severity:\s*["']?(\w+)/m, yaml, capture: :all_but_first)

    %{
      min_severity: if(min && hd(min) in @severities, do: hd(min), else: "style"),
      disabled_rules:
        Regex.scan(~r/ETC-[A-Z]+-\d+/, list_value(yaml, "disabled_rules")) |> List.flatten(),
      disabled_categories:
        Regex.scan(~r/[a-z_]+/, list_value(yaml, "disabled_categories")) |> List.flatten()
    }
  end

  # The value of a YAML list key, flow (`[a, b]`) or block (`- a`), as raw text.
  defp list_value(yaml, key) do
    case Regex.run(~r/^#{key}:(.*(?:\n[ \t]+.*|\n[ \t]*-.*)*)/m, yaml, capture: :all_but_first) do
      [value] -> value |> String.split("\n") |> Enum.map_join("\n", &strip_comment/1)
      nil -> ""
    end
  end

  defp strip_comment(line), do: line |> String.split("#", parts: 2) |> hd()

  defp vet(findings, ctx) do
    findings
    |> Enum.map(&normalize(&1, ctx))
    |> Enum.split_with(&(&1.drop == nil))
    |> then(fn {kept, dropped} -> {Enum.sort_by(kept, &sort_key/1), dropped} end)
  end

  defp normalize(finding, ctx) do
    rule = ctx.rules[finding["rule_id"]]
    file = finding["file"]
    line = finding["line"]

    %{
      rule_id: finding["rule_id"],
      severity: rule && rule.severity,
      rule_title: rule && rule.title,
      rule_path: rule && rule.path,
      file: file,
      line: line,
      occurrences: max(finding["occurrences"] || 1, 1),
      title: one_line(finding["title"] || (rule && rule.title) || ""),
      why: String.trim(finding["why"] || ""),
      fix: String.trim(finding["fix"] || ""),
      drop: drop_reason(rule, file, line, ctx)
    }
  end

  defp drop_reason(nil, _file, _line, _ctx), do: "cites a rule that does not exist"

  defp drop_reason(rule, file, line, %{added: added, config: config}) do
    cond do
      not is_map_key(added, file) ->
        "is in a file this pull request did not change"

      not is_integer(line) or not near_added?(added[file], line) ->
        "is on a line this pull request did not add"

      rank(rule.severity) > rank(config.min_severity) ->
        "is below min_severity in .test_critic.yml"

      rule.category in config.disabled_categories ->
        "is in a category disabled in .test_critic.yml"

      rule.id in config.disabled_rules ->
        "is a rule disabled in .test_critic.yml"

      true ->
        nil
    end
  end

  defp near_added?(lines, line),
    do: Enum.any?((line - @line_slack)..(line + @line_slack), &(&1 in lines))

  defp sort_key(finding), do: {rank(finding.severity), finding.file, finding.line}
  defp rank(severity), do: Enum.find_index(@severities, &(&1 == severity))

  defp counts(findings) do
    Map.merge(Map.new(@severities, &{&1, 0}), Enum.frequencies_by(findings, & &1.severity))
  end

  ## Rendering

  defp comment(%{score: 5}, _ctx), do: nil

  defp comment(report, ctx) do
    loud = Enum.filter(report.findings, &(&1.severity in ~w(critical warning)))
    {shown, rest} = Enum.split(loud, @comment_limit)

    """
    #{@marker}
    ### Elixir Test Critic: #{report.score}/5

    #{headline(report)} Advisory only, it never blocks a merge.

    #{Enum.map_join(shown, "\n", &comment_line(&1, ctx))}
    #{if rest != [], do: "\nand #{length(rest)} more in the full report.\n"}
    <sub>[Full report](#{ctx.report_url}) has the fixes#{quiet_tail(report.counts)}. \
    Reviewed #{short(ctx.sha)}. Comment `@test-critic` to run it again. \
    Mute a rule in `.test_critic.yml`.</sub>
    #{machine_line(report)}
    """
  end

  defp comment_line(finding, ctx) do
    "- #{icon(finding.severity)} [#{finding.rule_id}](#{rule_url(finding, ctx)}) " <>
      "[`#{Path.basename(finding.file)}:#{finding.line}`](#{line_url(finding, ctx)}) " <>
      finding.title <> times(finding)
  end

  defp summary(report, ctx) do
    [
      "**#{report.score}/5.** #{headline(report)}",
      for severity <- @severities,
          findings = Enum.filter(report.findings, &(&1.severity == severity)),
          findings != [] do
        section(severity, findings, ctx)
      end,
      strengths(report.strengths),
      dropped(report.dropped),
      "Scoring: 5 is no critical or warning finding. Up to two warnings is 4, three or more is 3. " <>
        "One critical finding is 2, more is 1. Recommendations and style notes never change the score.",
      machine_line(report)
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp section(severity, findings, ctx) when severity in ~w(critical warning) do
    [
      "## #{icon(severity)} #{label(severity, length(findings))}"
      | Enum.map(findings, &detail(&1, ctx))
    ]
  end

  defp section(severity, findings, ctx) do
    """
    <details><summary>#{label(severity, length(findings))}</summary>

    #{Enum.map_join(findings, "\n\n", &detail(&1, ctx))}

    </details>\
    """
  end

  defp detail(finding, ctx) do
    """
    **[#{finding.rule_id}](#{rule_url(finding, ctx)}) #{finding.title}**#{times(finding)}
    [`#{finding.file}:#{finding.line}`](#{line_url(finding, ctx)})

    #{finding.why}

    #{fix(finding.fix)}\
    """
    |> String.trim_trailing()
  end

  defp fix(""), do: ""

  defp fix(text) do
    if String.contains?(text, "\n") and not String.contains?(text, "```"),
      do: "Fix:\n\n```elixir\n#{text}\n```",
      else: "Fix: #{text}"
  end

  defp strengths([]), do: nil

  defp strengths(notes),
    do:
      "**What the changed tests do well**\n\n" <> Enum.map_join(notes, "\n", &"- #{one_line(&1)}")

  defp dropped([]), do: nil

  defp dropped(dropped) do
    lines =
      Enum.map_join(
        dropped,
        "\n",
        &"- #{&1.rule_id || "no rule"} at `#{&1.file}:#{&1.line}` #{&1.drop}"
      )

    "<details><summary>#{length(dropped)} not reported</summary>\n\n#{lines}\n\n</details>"
  end

  defp check(report, ctx) do
    %{
      name: @check_name,
      head_sha: ctx.sha,
      status: "completed",
      conclusion: if(report.score == 5, do: "success", else: "neutral"),
      output: %{
        title: "#{report.score}/5 · #{tally(report.counts)}",
        summary: summary(report, ctx),
        annotations: report.findings |> Enum.take(@annotation_limit) |> Enum.map(&annotation/1)
      }
    }
  end

  defp annotation(finding) do
    %{
      path: finding.file,
      start_line: finding.line,
      end_line: finding.line,
      annotation_level:
        if(finding.severity in ~w(critical warning), do: "warning", else: "notice"),
      title: "#{finding.rule_id} (#{finding.severity}): #{finding.title}",
      message: String.trim("#{finding.why}\n\n#{finding.fix}")
    }
  end

  defp headline(%{counts: counts, files: files}) do
    scope = "the test lines this pull request changes in #{plural(files, "file")}"

    case loud_tally(counts) do
      "" -> "No critical or warning finding on #{scope}."
      tally -> "#{String.capitalize(tally)} on #{scope}."
    end
  end

  defp loud_tally(counts), do: counts |> Map.take(~w(critical warning)) |> tally_of()

  defp tally(counts) do
    case tally_of(counts) do
      "" -> "clean"
      text -> text
    end
  end

  defp tally_of(counts) do
    for(
      severity <- @severities,
      (n = counts[severity] || 0) > 0,
      do: label(severity, n) |> String.downcase()
    )
    |> Enum.join(", ")
  end

  defp quiet_tail(counts) do
    case counts |> Map.take(~w(recommendation style)) |> tally_of() do
      "" -> ""
      tally -> ", plus #{tally}"
    end
  end

  defp machine_line(report) do
    fields = Enum.map_join(@severities, " ", &"#{&1}=#{report.counts[&1]}")
    "<!-- elixir-test-critic:score=#{report.score} #{fields} -->"
  end

  defp label("critical", n), do: "#{n} critical"
  defp label("warning", n), do: plural(n, "warning")
  defp label("recommendation", n), do: plural(n, "recommendation")
  defp label("style", n), do: plural(n, "style note")

  defp plural(1, word), do: "1 #{word}"
  defp plural(n, word), do: "#{n} #{word}s"

  defp icon("critical"), do: "🔴"
  defp icon("warning"), do: "🟡"
  defp icon(_severity), do: "⚪"

  defp times(%{occurrences: 1}), do: ""
  defp times(%{occurrences: n}), do: " (#{n} places)"

  defp rule_url(finding, ctx), do: "#{@rules_repo}/blob/#{ctx.critic_ref}/#{finding.rule_path}"

  defp line_url(finding, ctx),
    do: "https://github.com/#{ctx.repo}/blob/#{ctx.sha}/#{finding.file}#L#{finding.line}"

  defp short(sha), do: "`#{String.slice(sha, 0, 7)}`"
  defp one_line(text), do: text |> String.replace(~r/\s+/, " ") |> String.trim()

  defp front_matter(content) do
    case String.split(content, ~r/^---\s*$/m, parts: 3) do
      [_, front, _] -> front
      _ -> ""
    end
  end

  defp field(front, name) do
    case Regex.run(~r/^#{name}:\s*["']?(.*?)["']?\s*$/m, front, capture: :all_but_first) do
      [value] when value != "" -> value
      _ -> nil
    end
  end
end
