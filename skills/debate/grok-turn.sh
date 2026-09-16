#!/usr/bin/env bash
# grok-turn.sh — one headless Grok Build turn (used by Claude for debate / adversarial design review)
#
# Usage:
#   grok-turn.sh <prompt-file> [session-id|new] [max-turns]
#
# - prompt-file : file containing the prompt for Grok (avoids shell quoting issues)
# - session-id  : sessionId from a previous turn. Omit or "new" for a fresh session
# - max-turns   : how many internal tool calls Grok may make (default 8: file reads, greps…;
#                 use 15 for a large design review)
#
# Output: one JSON line {"sessionId":"…","text":"…","cost":0.01,"stopReason":"end_turn"}
# Grok runs in plan mode (read-only) and cannot modify files. Editing is Claude's job.
# Always runs from the repository root so Grok's exploration is anchored the same way regardless of
# where the caller is.
set -euo pipefail

PROMPT_FILE="${1:?prompt file required}"
SESSION="${2:-new}"
MAX_TURNS="${3:-8}"

for bin in grok jq git; do
  command -v "$bin" >/dev/null 2>&1 || { echo "{\"error\":\"$bin not found in PATH\"}"; exit 2; }
done
[[ -r "$PROMPT_FILE" ]] || { echo "{\"error\":\"prompt file not readable: $PROMPT_FILE\"}"; exit 2; }

PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo '{"error":"not inside a git repository"}'; exit 2; }
cd "$REPO_ROOT"

args=(--output-format json --permission-mode plan --max-turns "$MAX_TURNS" --prompt-file "$PROMPT_FILE")
if [[ "$SESSION" != "new" && -n "$SESSION" ]]; then
  args=(--resume "$SESSION" "${args[@]}")
fi

mkdir -p /tmp/team
raw="$(grok "${args[@]}" 2>>/tmp/team/grok-stderr.log)" || {
  echo '{"error":"grok exited non-zero (see /tmp/team/grok-stderr.log)","raw":'"$(printf '%s' "$raw" | jq -Rs .)"'}'
  exit 1
}

# Parse from the first '{' in case grok prints log lines around the JSON
printf '%s' "$raw" | sed -n '/^{/,$p' | jq -c '{sessionId, text, cost: .total_cost_usd, stopReason}'
