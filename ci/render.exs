# Renders a model review into the GitHub comment, check run and report.
#
#   elixir -r lib/test_critic/pr_report.ex ci/render.exs <work-dir>
#
# <work-dir> is the `pr/` directory from ci/collect.sh plus review.txt, the
# model's reply. Also reads the REPO, SHA and CRITIC_REF env vars.
# Writes: comment.md (absent when there is nothing to say), check.json,
# report.md and result.json.

alias TestCritic.PrReport

[dir] = System.argv()
read = fn name -> File.read(Path.join(dir, name)) end
write = fn name, text -> File.write!(Path.join(dir, name), text) end

ctx = %{
  rules: PrReport.rule_index(Path.join(Path.dirname(__DIR__), "rules")),
  added: PrReport.added_lines(File.read!(Path.join(dir, "diff.patch"))),
  config:
    PrReport.config(
      with {:ok, yaml} <- read.("files/.test_critic.yml"), do: yaml, else: (_ -> nil)
    ),
  repo: System.fetch_env!("REPO"),
  sha: System.fetch_env!("SHA"),
  critic_ref: System.get_env("CRITIC_REF", "main"),
  files: Path.join(dir, "changed.txt") |> File.stream!() |> Enum.count(),
  # The check run does not exist yet; the caller swaps this for its URL.
  report_url: "REPORT_URL"
}

review =
  with {:ok, text} <- read.("review.txt"),
       [json] <- Regex.run(~r/\{.*\}/s, text),
       {:ok, review} <- JSON.decode(json) do
    review
  else
    _ -> nil
  end

report = PrReport.build(review, ctx)

if report.comment, do: write.("comment.md", report.comment)
write.("check.json", JSON.encode!(report.check))
write.("report.md", report.summary)

write.(
  "result.json",
  JSON.encode!(Map.take(report, [:score, :counts, :findings, :dropped, :strengths, :files]))
)

IO.puts("score=#{report.score || "none"} #{report.check.output.title}")
