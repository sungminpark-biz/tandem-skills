#!/usr/bin/env bash
# grok-turn.sh — one headless Grok Build turn (used by Claude for debate / adversarial design review)
#
# Usage:
#   grok-turn.sh <prompt-file> [session-id|new] [max-turns]
#
# - prompt-file : file containing the prompt for Grok (avoids shell quoting issues)
# - session-id  : sessionId from a previous turn. Omit or "new" for a fresh session
# - max-turns   : how many internal tool calls Grok may make (default 8: file reads, greps…;
#                 use 30 for a design review, 40 for a foundation review)
#
# Output: one JSON line {"sessionId":"…","text":"…","cost":0.01,"stopReason":"end_turn"}
#   On failure the line also has "error", and "maxTurns":true when the turn limit was hit.
#   maxTurns → resume the SAME sessionId ("stop exploring, answer now from what you have").
#   Never start a new session for that.
# A new session's id is chosen BEFORE starting and written to stderr and to
#   <prompt-file dir>/last-grok-session, so a killed call can be resumed with its context.
# Grok runs read-only (verified 2026-10-01, grok 1.0.46). Headless, any command that would need
# approval CANCELS the whole turn (stopReason "cancelled") instead of being refused — including harmless
# reads outside Grok's built-in read-only list (find, git -c …, web_fetch). So:
#   - READ_ONLY_ALLOW pre-approves the read commands reviews actually use. It repeats Grok's built-in
#     read-only commands too: allow rules only cover a chained command when EVERY segment matches one,
#     so `git log; file x` cancelled while each half alone ran. Deny rules refuse find -exec/-delete
#     gracefully (a denial is reported back, it does not cancel). awk/xargs are left out on purpose:
#     they can run other commands. The sandbox, not this list, is what stops writes.
#   - `git -c …` cannot be allowed by any rule, so RULES (appended to Grok's system prompt every call)
#     lists the allowed commands and forbids git -c.
#   - edit/write/question tools are removed; --sandbox read-only blocks writes to the project at the OS
#     level (it still allows /tmp and ~/.grok); --no-plan keeps it out of plan mode.
# Reasoning effort is not passed: it comes from ~/.grok/config.toml (xhigh). Editing is Claude's job.
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

READ_ONLY_ALLOW=()
for cmd in "git status" "git log" "git diff" "git show" "git ls-files" "git rev-parse" "git check-ignore" \
           "git blame" "ls" "cat" "head" "tail" "wc" "sort" "uniq" "cut" "echo" "grep" "rg" "pwd" \
           "find" "sed -n" "jq" "diff" "stat" "tree" "file" "nl" "du" "which" "realpath"; do
  READ_ONLY_ALLOW+=(--allow "Bash($cmd:*)")
done
READ_ONLY_ALLOW+=(--allow WebFetch
                  --deny 'Bash(find * -exec*)' --deny 'Bash(find * -execdir*)' --deny 'Bash(find * -ok*)'
                  --deny 'Bash(find * -delete*)')
RULES="You are a read-only reviewer running headless. A shell command outside this list cancels your whole
turn: git status/log/diff/show/blame/ls-files/rev-parse/check-ignore (plain git only, never git -c),
ls, cat, head, tail, wc, sort, uniq, cut, echo, pwd, grep, rg, find (no -exec or -delete), sed -n, jq, diff,
stat, tree, file, nl, du, which, realpath. Never write or redirect output into files, never run tests,
builds, installers or network commands; use web_search and web_fetch for the web."
args=(--output-format json --permission-mode dontAsk --sandbox read-only --no-plan
      --disallowed-tools search_replace,write,ask_user_question
      "${READ_ONLY_ALLOW[@]}" --rules "$RULES"
      --max-turns "$MAX_TURNS" --prompt-file "$PROMPT_FILE")
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
  # Next to the prompt file (= /tmp/team/<slug>/), so concurrent runs never overwrite each other.
  printf '%s\n' "$SESSION" > "$(dirname "$PROMPT_FILE")/last-grok-session"
  echo "grok session: $SESSION (resume with this id if the process is killed or times out)" >&2
fi

mkdir -p /tmp/team
ERR_FILE="$(mktemp "${TMPDIR:-/tmp}/grok-turn.XXXXXX")"
trap 'rm -f "$ERR_FILE"' EXIT
code=0
raw="$(grok "${args[@]}" 2>"$ERR_FILE")" || code=$?
cat "$ERR_FILE" >> /tmp/team/grok-stderr.log
err="$(tail -n 5 "$ERR_FILE")"                                   # shown as the error message
max_turns=false
grep -qi 'max turns' "$ERR_FILE" && max_turns=true               # searched in the whole stderr

# grok prints its JSON (pretty-printed, opening '{' on a line of its own) even on failure,
# e.g. max turns → exit 1; take it from the first line that starts with '{' and parse it either way.
json="$(printf '%s' "$raw" | sed -n '/^{/,$p')"
if printf '%s' "$json" | jq -e 'type == "object"' >/dev/null 2>&1; then
  printf '%s' "$json" | jq -c --arg sid "$SESSION" --arg err "$err" --argjson code "$code" \
    --argjson mt "$max_turns" '
    {sessionId: (.sessionId // $sid), text, cost: .total_cost_usd, stopReason}
    + (if $code == 0 then {} else
        {error: (if $err == "" then "grok exited \($code)" else $err end), maxTurns: $mt}
      end)'
else
  jq -nc --arg sid "$SESSION" --arg err "$err" --arg raw "$raw" --argjson code "$code" \
    --argjson mt "$max_turns" \
    '{error: (if $err == "" then "grok exited \($code) without JSON" else $err end),
      maxTurns: $mt, sessionId: $sid, raw: $raw}'
  [[ $code -ne 0 ]] || code=1
fi
exit "$code"
