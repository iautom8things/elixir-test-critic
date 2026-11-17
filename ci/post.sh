#!/usr/bin/env bash
# Publishes a rendered review: a check run with the full report and inline
# annotations, and one comment that is edited in place on later runs.
#
#   post.sh <owner/repo> <pr-number> <dir-with-rendered-files> [always-comment]
#
# The check never fails. A clean review posts no comment unless one already
# exists or `always-comment` is `true` (someone asked by mention).
set -euo pipefail

repo=$1 pr=$2 dir=$3 always=${4:-false}
marker='<!-- elixir-test-critic -->'

report_url=$(gh api "repos/$repo/check-runs" --input "$dir/check.json" --jq .html_url)
echo "report: $report_url"

existing=$(gh api "repos/$repo/issues/$pr/comments" --paginate \
  --jq "[.[] | select(.body | startswith(\"$marker\"))] | last | .id // empty" | tail -1)

if [ -f "$dir/comment.md" ]; then
  sed "s#REPORT_URL#$report_url#g" "$dir/comment.md" > "$dir/comment.final.md"
elif [ -n "$existing" ] || [ "$always" = true ]; then
  title=$(jq -r .output.title "$dir/check.json")
  printf '%s\n**Elixir Test Critic: %s.** Nothing critical or warning on the test lines this pull request changes. [Full report](%s)\n' \
    "$marker" "$title" "$report_url" > "$dir/comment.final.md"
else
  exit 0
fi

if [ -n "$existing" ]; then
  gh api -X PATCH "repos/$repo/issues/comments/$existing" -F "body=@$dir/comment.final.md" --jq .html_url
else
  gh api "repos/$repo/issues/$pr/comments" -F "body=@$dir/comment.final.md" --jq .html_url
fi
