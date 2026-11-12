#!/usr/bin/env bash
# Runs the review prompt through a model CLI with read-only tools.
#
#   review.sh <copilot|claude> <model> <work-dir>
#
# <work-dir> holds `pr/` from collect.sh. Writes <work-dir>/pr/review.txt.
set -euo pipefail

engine=$1 model=$2 work=$3
here=$(cd "$(dirname "$0")" && pwd)
# Copied, not linked: the Copilot CLI refuses to read through a link that
# leaves its working directory.
mkdir -p "$work/critic"
cp -R "$here/../rules" "$here/../toc" "$work/critic/"
cd "$work"
raw=$(mktemp)
prompt=$(cat "$here/review-pr.md")

case "$engine" in
  copilot)
    copilot -p "$prompt" --model "$model" --available-tools view grep glob --allow-all-tools \
      --no-custom-instructions --no-ask-user --no-auto-update --output-format json < /dev/null > "$raw"
    jq -rs '[.[] | select(.type == "assistant.message")] | last | .data.content' "$raw" > pr/review.txt
    jq -c 'select(.type == "result") | .usage' "$raw"
    ;;
  claude)
    claude -p "$prompt" --model "$model" --allowedTools Read Grep Glob \
      --disallowedTools Bash Write Edit Agent WebFetch WebSearch \
      --strict-mcp-config --setting-sources "" --output-format json < /dev/null > "$raw"
    jq -r .result "$raw" > pr/review.txt
    jq -c '{cost_usd: .total_cost_usd, turns: .num_turns, seconds: (.duration_ms / 1000 | floor)}' "$raw"
    ;;
  *)
    echo "unknown engine: $engine" >&2
    exit 2
    ;;
esac
