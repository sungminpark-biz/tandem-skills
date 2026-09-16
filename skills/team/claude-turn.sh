#!/usr/bin/env bash
# claude-turn.sh — one headless Claude Code turn (used by Grok to get design/review from Claude)
#
# Usage:
#   claude-turn.sh <mode> <prompt-file> [session-id|new]
#
# - mode        : design | review
#     design → only docs/design/** is writable; writes elsewhere are refused by the harness (dontAsk).
#               Read-only Bash only.
#     review → Read + Bash (to run tests). Write/Edit and common mutating Bash
#               (git commit/checkout/reset, rm, mv, sed -i, …) are blocked.
# - prompt-file : file containing the prompt for Claude
# - session-id  : sessionId from a previous turn. Omit or "new" for a fresh session
#                 (design revisions and reviews should resume the design session)
#
# Output: one JSON line
#   {"sessionId":"…","text":"…","cost":0.3,"isError":false,"subtype":"success"}
#   If subtype is "error_max_turns", resume the same sessionId with "continue and finish".
#
# Recovery from timeouts / kills: a new session's id is chosen BEFORE starting and written to
#   stderr and /tmp/team/last-claude-session. If the process dies, run
#   `claude-turn.sh <mode> <new-prompt> <id>` to continue with the exploration context intact.
# Claude's stderr goes to /tmp/team/claude-stderr.log (auth/config errors).
#
# Claude loads CLAUDE.md and its project memory, so it knows the repository's rules.
set -euo pipefail

MODE="${1:?mode required: design|review}"
PROMPT_FILE="${2:?prompt file required}"
SESSION="${3:-new}"

for bin in claude jq git; do
  command -v "$bin" >/dev/null 2>&1 || { echo "{\"error\":\"$bin not found in PATH\"}"; exit 2; }
done
[[ -r "$PROMPT_FILE" ]] || { echo "{\"error\":\"prompt file not readable: $PROMPT_FILE\"}"; exit 2; }

# Pin the prompt file to an absolute path, then always run claude from the repository root.
# (Permission patterns like Write(docs/design/**) are relative to cwd, so results must not depend
#  on where the caller happens to be.)
PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo '{"error":"not inside a git repository"}'; exit 2; }
cd "$REPO_ROOT"

READ_ONLY_BASH="Bash(git *),Bash(ls *),Bash(cat *),Bash(find *),Bash(rg *),Bash(grep *),Bash(sed -n *),Bash(head *),Bash(tail *),Bash(wc *),Bash(tree *),Bash(node -v),Bash(node --version),Bash(pnpm -v),Bash(npm -v),Bash(python* --version),Bash(pipenv --version)"
# Common file-mutating commands during review. Not exhaustive — the prompt's "do not modify files"
# is the second line of defense.
MUTATING_BASH="Bash(git commit *),Bash(git checkout *),Bash(git switch *),Bash(git restore *),Bash(git reset *),Bash(git stash *),Bash(git clean *),Bash(git push *),Bash(git rebase *),Bash(git merge *),Bash(rm *),Bash(mv *),Bash(sed -i *),Bash(chmod *)"

case "$MODE" in
  design)
    args=(--permission-mode dontAsk
          --allowedTools "Read,Grep,Glob,Write(docs/design/**),Edit(docs/design/**),${READ_ONLY_BASH}"
          --max-turns 80)
    ;;
  review)
    args=(--permission-mode dontAsk
          --allowedTools "Read,Grep,Glob,Bash"
          --disallowedTools "Write,Edit,NotebookEdit,${MUTATING_BASH}"
          --max-turns 80)
    ;;
  *) echo '{"error":"mode must be design|review"}'; exit 2 ;;
esac

mkdir -p /tmp/team
if [[ "$SESSION" != "new" && -n "$SESSION" ]]; then
  args=(--resume "$SESSION" "${args[@]}")
else
  if command -v uuidgen >/dev/null 2>&1; then
    SESSION="$(uuidgen | tr 'A-Z' 'a-z')"
  else
    SESSION="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  fi
  args=(--session-id "$SESSION" "${args[@]}")
  printf '%s\n' "$SESSION" > /tmp/team/last-claude-session
  echo "claude session: $SESSION (resume with this id if the process is killed or times out)" >&2
fi

STDERR_LOG=/tmp/team/claude-stderr.log
# < /dev/null : skip claude -p's 3-second wait for piped stdin
raw="$(claude -p "$(cat "$PROMPT_FILE")" --output-format json "${args[@]}" < /dev/null 2>>"$STDERR_LOG")" || {
  echo '{"error":"claude exited non-zero (see /tmp/team/claude-stderr.log)","sessionId":"'"$SESSION"'","raw":'"$(printf '%s' "$raw" | jq -Rs .)"'}'
  exit 1
}

printf '%s' "$raw" | jq -c '{sessionId: .session_id, text: .result, cost: .total_cost_usd, isError: .is_error, subtype}'
