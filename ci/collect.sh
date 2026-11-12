#!/usr/bin/env bash
# Collects what a pull request changed in its tests, through the GitHub API.
# Nothing from the pull request is checked out or run.
#
#   collect.sh <owner/repo> <pr-number> <out-dir>
#
# Writes <out-dir>/diff.patch, <out-dir>/files/ (head copies of the changed
# test files, mix.exs and .test_critic.yml) and <out-dir>/changed.txt.
# Prints `sha=`, `files=` and `hash=` lines for $GITHUB_OUTPUT.
set -euo pipefail

repo=$1 pr=$2 out=$3
tests='_test\\.exs$|^test/support/|(^|/)test_helper\\.exs$'
mkdir -p "$out/files"

sha=$(gh api "repos/$repo/pulls/$pr" --jq .head.sha)
gh api "repos/$repo/pulls/$pr/files" --paginate \
  --jq ".[] | select(.status != \"removed\") | select(.filename | test(\"$tests\"))" \
  | jq -s . > "$out/files.json"

jq -r '.[].filename' "$out/files.json" > "$out/changed.txt"
jq -r '.[] | "diff --git a/\(.filename) b/\(.filename)\n--- a/\(.filename)\n+++ b/\(.filename)\n\(.patch // "")"' \
  "$out/files.json" > "$out/diff.patch"

fetch() {
  mkdir -p "$out/files/$(dirname "$1")"
  gh api "repos/$repo/contents/$1?ref=$sha" -H "Accept: application/vnd.github.raw" > "$out/files/$1" 2>/dev/null \
    || rm -f "$out/files/$1"
}

while read -r file; do fetch "$file"; done < "$out/changed.txt"
fetch mix.exs
fetch .test_critic.yml

echo "sha=$sha"
echo "files=$(wc -l < "$out/changed.txt" | tr -d ' ')"
echo "hash=$(cat "$out/diff.patch" "$out/files/.test_critic.yml" 2>/dev/null | shasum -a 256 | cut -c1-16)"
