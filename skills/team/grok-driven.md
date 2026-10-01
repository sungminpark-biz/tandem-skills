# /team: Grok-driven feature mode

Part of the team skill, read by Grok Build when it is the driver. Section ids (T1–T6) and the
Shared rules are in `~/.claude/skills/team/SKILL.md`, which is already loaded.

## G. Grok-driven feature mode (fallback)

For when Grok Build is the session (no Orca, or the user prefers it). Grok is the driver. Claude is
called headlessly several times (design draft once, design revision ≤2, code review ≤3 — all resuming
the same session). Claude loads `CLAUDE.md` and its project memory, so it knows the repository's
rules and history.

**Entry `/team implement <design doc path>`**: the design was already reviewed and approved in Claude
Code. Skip to G-2. There is no Claude session yet: the first time G-2 or G-3 needs Claude, start one
with `new` (say the design at <path> was approved in Claude Code), keep that `sessionId`, and resume
it afterwards.

### Tools
```bash
bash ~/.claude/skills/team/claude-turn.sh <design|review> <prompt-file> [session-id|new]
# → {"sessionId":"…","text":"…","cost":0.3,"isError":false,"subtype":"success"}
```
- `design`: only `docs/design/**` is writable, except `docs/design/foundation/` (foundation work is
  Claude Code's job) — other writes are refused by the harness. Bash runs only what Claude Code
  classifies as read-only (git log/diff/show, grep, find, ls…); git branch/stash/commit and file
  writes through the shell are refused. WebSearch, WebFetch and context7 are allowed (context7 needs
  a one-time `/mcp` login in an interactive Claude Code session; until then it is refused); anything
  refused ends up as `not verified` (T1).
- `review`: Read + Bash (to run tests). Write/Edit and mutating Bash (git commit/checkout/reset,
  rm, mv, sed -i, …) are blocked.
- Allow rules in the user's own Claude Code settings still apply in both modes.
- The script `cd`s to the repository root itself, so it works from any directory.
- Always pass prompts as files (avoids shell quoting), in `/tmp/team/<slug>/`.
- If the result's `subtype` is `error_max_turns` (the script exits 1 then, but the line still has
  `subtype` and `sessionId`), or `text` lacks the expected marker (`DESIGN_DOC:` / `## Verdict:`),
  resume **the same sessionId** once with "continue and finish". Never start a new session for that.
- Roughly 0.3–2 USD per call. **A large design takes 20–40 minutes.** Run it as a background task and
  wait with `timeout_ms` 3600000 (Grok clamps a wait to 1 hour); if the wait returns while it is still
  running, wait again, never kill it. Killing at 25 minutes throws away all exploration done so far.
- The script prints the new session id **before** starting, to stderr and to
  `last-claude-session` next to the prompt file (`/tmp/team/<slug>/last-claude-session`). If the
  process is killed or times out, do not start over — resume that id and say "write the design doc
  now from what you have already learned". The exploration context is still there.

### G-1. Design request → `team-design.md`
```
Role: senior architect for this repository. Repository: <cwd>
Task request: <the user's request, verbatim>
Job: read the code and write a design document at docs/design/<YYYYMMDD>-<slug>.md. Do not modify source files.
The document must contain: <paste the T1 list verbatim>
Method: <paste the T1 method paragraph verbatim>
Write in the user's language. Print "DESIGN_DOC: <absolute path>" as the last line.
```
```bash
bash ~/.claude/skills/team/claude-turn.sh design /tmp/team/<slug>/team-design.md new   # keep the sessionId
```
Read the `DESIGN_DOC:` path from `text`. **Keep the sessionId** — every later design revision and
code review resumes this session.

### G-1b. Adversarial design review (Grok itself) — mandatory before implementing
Review the design doc with the T2 checklist and write `/tmp/team/<slug>/design-review-<N>.md` in the
T2 format. If Critical, Missing and Ambiguous are **all empty**, skip G-1c and go to G-1d. Otherwise G-1c.

### G-1c. Claude rebuts/accepts + revises the doc (resume the design session, `design` mode)
```
Grok has adversarially reviewed your design. Review file: /tmp/team/<slug>/design-review-<N>.md
Judge every item by checking the code directly:
- Correct → accept and Edit the design doc
- Wrong → rebut with evidence (file:line). Leave the doc unchanged
- Needs checking → actually check (grep / read the file) before judging. No guessing
For Ambiguous items, write the answer into the doc (so the implementer never has to ask again).
Output: a per-item list of "accepted (doc §x changed) | rebutted (evidence)". Last line "DESIGN_DOC: <path>".
```
```bash
bash ~/.claude/skills/team/claude-turn.sh design /tmp/team/<slug>/team-design-fix-<N>.md <sessionId>
```
Grok re-reads the revised doc and Claude's rebuttals. Accept rebuttals that are backed by evidence.
**If Critical items remain and you cannot accept Claude's rebuttal**, run G-1b once more (design
review total ≤2). If Critical items are still contested after 2 rounds → do not implement; set the
slice `blocked` (if there is a foundation), report both sides' evidence to the user and stop. No
Critical items left (Missing/Ambiguous now reflected in the doc) → G-1d.

### G-1d. Approval gate
T3. Change requests go to Claude: put them in `team-design-fix-user.md` and resume the design session
(`design` mode) → doc revised → show the gate again.

### G-2. Implementation (Grok itself)
Load the `ponytail` skill (full) before writing code; within the design (Shared rules), it decides how
the code is written. Follow the design doc's scope, signatures and order exactly. Never modify files
outside the scope. If you conclude the design must be deviated from, ask Claude before implementing
that part (the Claude session, `design` mode — so a changed decision lands in the doc; Claude can't
touch source anyway). Do not implement that part until you have the answer. If the answer is that the change
contradicts the foundation or needs a new expensive decision → "Foundation change needed" below. Run
the definition-of-done tests yourself and make them pass. Do not commit.

**Foundation change needed.** Grok cannot run F-change (foundation work is Claude-only, and headless
design mode cannot write `docs/design/foundation/`): stop implementing, set the slice to
`blocked: <reason>`, tell the user to run `/team foundation change: <what and why>` in Claude Code,
and stop.

### G-3. Code review request → `team-review.md` (resume the Claude session)
```
Role: reviewer. Check whether the implementation matches the design doc: <path>.
Inspect the change with git diff and git status, and run the definition-of-done tests yourself (do not modify files).
Check: omissions/additions vs the design, scope violations, test results, regression risk, existing code conventions (minimal change).
Then invoke the ponytail:ponytail-review skill (Skill tool) on the same diff. Accept an item only if it keeps the design's interfaces, the definition of done and what ponytail never cuts (trust-boundary validation, data-loss handling, security, accessibility): accepted items go under Required changes, rejected ones under Suggestions with the reason.
Format: <paste T4 verbatim>
```
```bash
bash ~/.claude/skills/team/claude-turn.sh review /tmp/team/<slug>/team-review.md <sessionId>
```
- `REQUEST_CHANGES` → apply the required changes → repeat G-3 (same session; keep it short:
  "Fixed: … please re-review"). At most 3 rounds.
- Still not approved after 3 → set the slice `blocked` (if there is a foundation) and report the
  remaining items and both sides' reasoning to the user.
- `APPROVE` → G-4.

### G-4. Report
T5. If there is a foundation, set the slice to `done` in `slices.md`.
