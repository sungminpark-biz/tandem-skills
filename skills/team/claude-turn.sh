#!/usr/bin/env bash
# claude-turn.sh — one headless Claude Code turn (used by Grok to get design/review from Claude)
#
# Usage:
#   claude-turn.sh <mode> <prompt-file> [session-id|new]
#
# - mode        : design | review
#     design → only docs/design/** is writable, except docs/design/foundation/** (foundation docs are
#               changed only from an interactive Claude Code session); other writes are refused (dontAsk).
#               Bash runs only what Claude Code itself classifies as read-only (git log/diff/show,
#               grep, find, ls, cat…); git branch/stash/commit and other mutations are denied.
#     review → Read + Bash (to run tests). Write/Edit and common mutating Bash
#               (git commit/checkout/reset, rm, mv, sed -i, …) are blocked.
# - prompt-file : file containing the prompt for Claude
# - session-id  : sessionId from a previous turn. Omit or "new" for a fresh session
#                 (design revisions and reviews should resume the design session)
#
# Output: one JSON line
#   {"sessionId":"…","text":"…","cost":0.3,"isError":false,"subtype":"success"}
#   If subtype is "error_max_turns", resume the same sessionId with "continue and finish".
#   (claude exits non-zero then; the line still carries subtype and sessionId.)
#
# Recovery from timeouts / kills: a new session's id is chosen BEFORE starting and written to
#   stderr and <prompt-file dir>/last-claude-session (per task, so concurrent runs never overwrite
#   each other). If the process dies, run `claude-turn.sh <mode> <new-prompt> <id>` to continue with
#   the exploration context intact.
# Claude's stderr goes to /tmp/team/claude-stderr.log (auth/config errors).
#
# Claude loads CLAUDE.md and its project memory, so it knows the repository's rules.
# Allow rules in your own Claude Code settings still apply in both modes (dontAsk only refuses what
# nothing allows). The deny list below overrides them for the commands it names.
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

# Common file-mutating commands. Denied in both modes, which also overrides broader allow rules
# (e.g. Bash(git *)) in the user's settings. Not exhaustive — in review mode the prompt's
# "do not modify files" is the second line of defense.
MUTATING_BASH="Bash(git commit *),Bash(git checkout *),Bash(git switch *),Bash(git restore *),Bash(git reset *),Bash(git stash *),Bash(git clean *),Bash(git push *),Bash(git rebase *),Bash(git merge *),Bash(git branch -d *),Bash(git branch -D *),Bash(git branch -f *),Bash(git worktree remove *),Bash(git worktree prune*),Bash(git -c *),Bash(rm *),Bash(mv *),Bash(sed -i *),Bash(chmod *)"

case "$MODE" in
  design)
    # No Bash allow rules on purpose: Claude Code auto-approves commands it classifies as read-only,
    # and dontAsk refuses the rest. A hand-written allowlist like Bash(git *) let `git stash` through.
    args=(--permission-mode dontAsk
          --allowedTools "Read,Grep,Glob,Write(docs/design/**),Edit(docs/design/**)"
          --disallowedTools "NotebookEdit,Write(docs/design/foundation/**),Edit(docs/design/foundation/**),${MUTATING_BASH}"
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
  elif [[ -r /proc/sys/kernel/random/uuid ]]; then
    SESSION="$(cat /proc/sys/kernel/random/uuid)"
  elif command -v python3 >/dev/null 2>&1; then
    SESSION="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  else
    echo '{"error":"need uuidgen, /proc/sys/kernel/random/uuid or python3 to create a session id"}'; exit 2
  fi
  args=(--session-id "$SESSION" "${args[@]}")
  printf '%s\n' "$SESSION" > "$(dirname "$PROMPT_FILE")/last-claude-session"
  echo "claude session: $SESSION (resume with this id if the process is killed or times out)" >&2
fi

STDERR_LOG=/tmp/team/claude-stderr.log
code=0
# < /dev/null : skip claude -p's 3-second wait for piped stdin
raw="$(claude -p "$(cat "$PROMPT_FILE")" --output-format json "${args[@]}" < /dev/null 2>>"$STDERR_LOG")" || code=$?

# claude prints its result JSON even when it exits non-zero (e.g. error_max_turns → exit 1),
# so parse it either way; only fall back to an error line when there is no JSON at all.
if printf '%s' "$raw" | jq -e 'type == "object"' >/dev/null 2>&1; then
  printf '%s' "$raw" | jq -c --arg sid "$SESSION" \
    '{sessionId: (.session_id // $sid), text: .result, cost: .total_cost_usd, isError: .is_error, subtype}'
else
  jq -nc --arg sid "$SESSION" --arg raw "$raw" --argjson code "$code" \
    '{error: "claude exited \($code) without a JSON result (see /tmp/team/claude-stderr.log)",
      sessionId: $sid, raw: $raw}'
  [[ $code -ne 0 ]] || code=1
fi
exit "$code"
