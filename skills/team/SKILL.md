---
name: team
description: >-
  Cross-model agent team: Claude drafts the design -> Grok adversarially reviews it -> Claude
  revises -> human approves -> Grok implements -> Claude reviews the code. A Claude<->Grok take on
  Claude Code Agent Teams. Open one Grok Build session in a repo and say "/team <task>": Grok reads
  this skill, calls Claude headlessly for design and review, and implements the code itself. If run
  from Claude Code instead, Claude designs and reviews and spawns Grok as an Orca orchestration
  worker. Triggers: "/team", "have grok implement this", "design then let grok code", "work as a
  team", "like Agent Teams", "claude designs/reviews, I implement". Trivial edits (1-2 files) don't
  need a team - just do them.
argument-hint: "[feature or task to implement]"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# /team — design (Claude draft → Grok adversarial review → Claude revision) → implement (Grok) → code review (Claude)

This skill is loaded by both Claude Code and Grok Build. **The path depends on which agent is
executing it.** First decide who you are:

- **I am Grok → [A. Grok-driven](#a-grok-driven-default)** (the default usage: one Grok session in a worktree)
- **I am Claude → [B. Claude-driven](#b-claude-driven)**

Shared rules: design and code review belong to Claude, code writing belongs to Grok. **A design
draft goes to implementation only after Grok's adversarial review → Claude's rebuttal/acceptance
and revision** (design review ≤2 rounds, code review ≤3 rounds). Commit only when the user asks.
Never run verification that writes to production databases or external services. The user is
involved at exactly two points: **the approval gate after the design is final (mandatory)** and
when a business judgment (cost, customer impact, operating policy) is split. Otherwise don't
interrupt them. Write all user-facing output in the user's language.

Overall flow:
```
Claude design draft → Grok adversarial review → Claude rebut/accept + revise doc → (re-review ≤2)
→ ★ human approval gate (stop and wait) ★
→ Grok implements → Claude code review → Grok fixes → (re-review ≤3) → report
```

---

## A. Grok-driven (default)

Grok is the driver. Claude is called headlessly several times (design draft once, design revision
≤2, code review ≤3 — all resuming the same session). Claude loads `CLAUDE.md` and its project
memory, so it knows the repository's rules and history.

### Tools
```bash
bash ~/.claude/skills/team/claude-turn.sh <design|review> <prompt-file> [session-id|new]
# → {"sessionId":"…","text":"…","cost":0.3,"isError":false,"subtype":"success"}
```
- `design`: only `docs/design/**` is writable — writes anywhere else are refused by the harness
  (plan-mode-grade safety). Read-only Bash only.
- `review`: Read + Bash (to run tests). Write/Edit and mutating Bash (git commit/checkout/reset,
  rm, mv, sed -i, …) are blocked.
- The script `cd`s to the repository root itself, so it works from any directory.
- `<slug>` = a short kebab-case name for this task (e.g. `user-auth-refresh`). Use the same value
  for the design doc filename and the scratch directory `/tmp/team/<slug>/`.
- Always pass prompts as files (avoids shell quoting). Keep them outside the repo in
  `/tmp/team/<slug>/` so git stays clean.
- If the result's `subtype` is `error_max_turns`, or `text` lacks the expected marker
  (`DESIGN_DOC:` / `## Verdict:`), resume **the same sessionId** once with "continue and finish".
  Never start a new session for that.
- Roughly $0.3–2 per call. **A large design takes 20–40 minutes.** If Grok's Task/background tool
  has a kill deadline, disable it or set it generously (60 min+). Killing at 25 minutes throws away
  all exploration done so far.
- The script prints the new session id **before** starting (stderr and
  `/tmp/team/last-claude-session`). If the process is killed or times out, do not start over —
  resume that id and say "write the design doc now from what you have already learned". The
  exploration context is still there.

### A-1. Design request → `team-design.md`
```
Role: senior architect for this repository. Repository: <cwd>
Task request: <the user's request, verbatim>
Job: read the code and write a design document at docs/design/<YYYYMMDD>-<slug>.md. Do not modify source files.
The document must contain:
- Goal / background (one paragraph)
- Scope of change: list of files to modify or create (paths)
- Interfaces, schemas, function signatures (concrete enough that the implementer never guesses)
- Step-by-step implementation order
- Definition of done: test commands/conditions that must pass, manual checks
- Do-not-touch: files that must not change, forbidden actions
Method: don't explore for long. **Within 10 minutes, Write the document skeleton first (the section
headings above + what you already know), then fill it in with Edit as you investigate.** Do not exceed
40 tool calls. If this round has a defined implementation slice, detail only that slice and list the
rest as one-liners under a "Follow-ups" section.
Write in the user's language. Print "DESIGN_DOC: <absolute path>" as the last line.
```
```bash
bash ~/.claude/skills/team/claude-turn.sh design /tmp/team/<slug>/team-design.md new   # keep the sessionId
```
Read the `DESIGN_DOC:` path from `text`. **Keep the sessionId** — every later design revision and
code review resumes this session.

### A-1b. Adversarial design review (Grok itself) — mandatory before implementing
Read the design doc **in full** and verify it against the repository directly. The goal is to
**break** the design. Don't list what you agree with — only problems. Attach evidence to each item
(file:line / observed behavior / RPC or schema contract). Checklist:
- Do the files in the scope actually exist? Is anything missing (call sites, tests, config, types)?
- Do signatures, schemas and RPC response shapes match the real code?
- Regression paths that break existing behavior; migrations, compatibility, rollback
- Is the definition of done actually runnable? Any verification gaps?
- For anything touching payments/DB/customers: double-processing, races, state on failure
- Anything an implementer would have to guess ("I couldn't build this as written")
Write the result to `/tmp/team/<slug>/design-review-<N>.md`:
```
## Critical (implementing as written would be wrong or break things) — evidence required
## Missing (needed but absent from the design)
## Ambiguous (things the implementer would have to guess — phrase as questions)
## Verdict: needs revision | ready to implement
```
If Critical, Missing and Ambiguous are **all empty**, skip A-1c and go to A-1d. Otherwise A-1c.

### A-1c. Claude rebuts/accepts + revises the doc (resume the design session, `design` mode)
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
**If Critical items remain and you cannot accept Claude's rebuttal**, run A-1b once more (design
review total ≤2). If Critical items are still contested after 2 rounds → do not implement; report
both sides' evidence to the user and stop. No Critical items left (Missing/Ambiguous now reflected
in the doc) → A-1d.

### A-1d. Human approval gate — always stop before implementing
Once the design is final, **do not start implementing**. Show the user the summary below, then
**end your turn and wait for their answer**:
```
## Design finalized — approval requested
- Document: docs/design/….md
- One-line summary: …
- Scope: N files (create …, modify …)
- Key decisions (3–5): …
- Adversarial review: Grok raised N items → Claude accepted N (what changed) / rebutted N (why)
- Definition of done: <test commands>
- Risks / things you should know: …
Reply "approve" or "go" to proceed. Otherwise tell me what to change.
```
- **"approve" / "go" / "proceed"** → A-2
- **Change requests** → put them in `team-design-fix-user.md` and send to Claude (resume the design
  session, `design` mode) → doc revised → summarize only what changed and re-run A-1d. If the
  request changes the design substantially, restart from A-1b.
- Never skip this gate. The only exception is when the user's original request explicitly said
  "proceed without approval".

### A-2. Implementation (Grok itself)
Follow the design doc's scope, signatures and order exactly. Never modify files outside the scope.
If you conclude the design must be deviated from, ask Claude before implementing that part (same
session, `design` mode — so a changed decision lands in the doc; Claude can't touch source anyway).
Do not implement that part until you have the answer. Run the definition-of-done tests yourself
and make them pass. Do not commit.

### A-3. Code review request → `team-review.md` (resume the design session)
```
Role: reviewer. Check whether the implementation matches the design doc you wrote: <path>.
Inspect the change with git diff and git status, and run the definition-of-done tests yourself (do not modify files).
Check: omissions/additions vs the design, scope violations, test results, regression risk, existing code conventions (minimal change).
Format:
## Verdict: APPROVE | REQUEST_CHANGES
## Required changes (file:line, what and how)
## Suggestions (optional)
## Test results
```
```bash
bash ~/.claude/skills/team/claude-turn.sh review /tmp/team/<slug>/team-review.md <sessionId>
```
- `REQUEST_CHANGES` → apply the required changes → repeat A-3 (same session; keep it short:
  "Fixed: … please re-review"). At most 3 rounds.
- Still not approved after 3 → report the remaining items and both sides' reasoning to the user.
- `APPROVE` → A-4.

### A-4. Report
```
## Result
- Design doc: docs/design/….md (Claude draft → Grok adversarial review ×N → Claude revision)
  - What the review changed: … / What Claude rebutted and kept: …
- Files changed: … (Grok)
- Code review: N rounds — what the review fixed: …
- Tests: <command> passed
- Total Claude cost: $X
## Open issues / decisions for the user
```
Inside Orca, also update the card:
`orca worktree set --worktree active --comment "implemented + reviewed: <feature>" --json`.

---

## B. Claude-driven

When run from a Claude Code session. Claude designs and reviews; Grok is launched as an Orca
orchestration worker (a real TUI with file-edit rights, visible to the user as a tab). **Orca
only** — if `orca status --json` or `orca worktree current --json` fails, tell the user and stop.
Verified 2026-09-16: `worker-start --agent grok` → Grok followed the injected preamble and replied
with `worker_done`.

### B-1. Design doc + Grok adversarial review (mandatory)
Write `docs/design/<YYYYMMDD>-<slug>.md` with the same sections as A-1. Then call Grok headlessly
(read-only) for an adversarial review using the A-1b checklist and format:
```bash
# The prompt file contains the A-1b checklist + output format + the design doc's absolute path
bash ~/.claude/skills/debate/grok-turn.sh /tmp/team/<slug>/design-review-req.md new 15
```
Check every Critical/Missing/Ambiguous item **against the code yourself**, then accept (revise the
doc) or rebut (with evidence). If Critical items remain and Grok needs to see the rebuttal, run one
more round in the same grok session (`sessionId`) — 2 rounds total. Still contested after 2 → do not
implement; report to the user. No Critical items → **the same human approval gate as A-1d**: show
the design summary, end your turn, wait for approval. Do not go to B-2 before approval. Approved → B-2.

### B-2. Run + Task + Grok worker
```bash
orca orchestration run-create --objective "<feature>" --json
orca orchestration task-create --spec "<spec>" --json                     # → task_id
orca orchestration worker-start --task <task_id> --worktree current --agent grok --timeout-ms 120000 --json
orca orchestration dispatch-show --task <task_id> --json                   # → ctx_… , assignee_handle
orca worktree set --worktree active --comment "grok implementing: <feature>" --json
```
Spec template:
```
Read the design doc first: <absolute path>. Implement its "<section>".
Definition of done: <test commands/conditions>. Include the passing results in the worker_done body.
Rules: do not modify files outside the doc's "scope of change". If you believe the design must be
deviated from, ask before implementing. Do not commit. On completion pass every modified file in
worker_done --files-modified.
```
Default: one Task = one Grok, same worktree. Parallelize only for independent chunks whose files
don't overlap.

### B-3. Wait + answer questions
```bash
orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 900000 --json
orca orchestration reply --id <msg_id> --body "<answer>" --json               # for question
orca orchestration check --ack <deliveryId> --wait --types worker_done,escalation,question --timeout-ms 900000 --json
```
Timeouts, `count: 0` and heartbeats are not failures (implementation takes 15–60 min). Progress:
`worker-read --dispatch <ctx_id> --limit 50 --json`. If the worker's output stalls for a long time,
`orca terminal read --terminal <assignee_handle> --json` — if the Grok TUI is **waiting on an
edit/command approval prompt**, release it with
`orca terminal send --terminal <assignee_handle> --text "y" --enter --json` (or whatever key the
prompt asks for). While Grok is dispatched, Claude does not edit source files.

### B-4. Review
`git diff` + **re-run the definition-of-done tests yourself**. Changes needed → reuse the same Grok:
```bash
orca orchestration task-create --spec "Apply review: <per-item instructions, file:line>" --json
orca orchestration worker-start --task <new_task_id> --terminal <assignee_handle> --json
```
→ B-3. At most 3 rounds.

### B-5. Wrap up
```bash
orca orchestration worker-release --dispatch <ctx_id> --json     # for every completed dispatch
orca orchestration check --ack <deliveryId> --json
orca worktree set --worktree active --comment "implemented + reviewed: <feature>" --json
```
Report format is the same as A-4. Never stop/release a worker because of a timeout or idle state.
If a handle returns `terminal_handle_stale`, re-acquire it with
`orca terminal list --worktree active --json`; never send to both old and new handles.
