---
name: team
description: >-
  Cross-model agent team: Claude designs and reviews, Grok implements. Feature mode (default): Claude
  drafts the design -> Grok adversarially reviews it -> Claude revises -> human approves -> Grok
  implements as an Orca worker -> Claude reviews the code. Foundation mode ("/team foundation
  <service>"): for a service designed from scratch or re-founded - Claude drafts the charter with the
  user, the expensive-to-reverse decisions and a slice map, Grok attacks them, the human approves,
  then every slice runs through feature mode. Run it from Claude Code (the default). From Grok Build,
  "/team <task>" still works as the fallback: Grok calls Claude headlessly for design and review and
  implements itself. Triggers: "/team", "/team foundation", "have grok implement this", "design then
  let grok code", "work as a team", "like Agent Teams", "design the whole service from scratch".
  Trivial edits (1-2 files) don't need a team - just do them.
argument-hint: "[foundation|implement] <feature, task, service or design doc>"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# /team — Claude designs and reviews, Grok implements

This skill is loaded by both Claude Code and Grok Build. First pick the mode, then the path.

## 0. Mode and path

**Mode** (from the request):
- **Foundation** — `/team foundation …`, or the request is a new service built from scratch, or a
  re-founding that changes several expensive-to-reverse decisions at once, or a change to an existing
  foundation → [F](#f-foundation-mode)
- **Feature** — everything else: one change set that fits one implementation run → feature mode

**Path** (from who is executing):
- **I am Claude** → foundation: F. Feature: **[C. Claude-driven](#c-claude-driven-feature-mode-default)
  (the default)**. C needs this worktree to be Orca-managed: `orca worktree current --json` returns
  `"ok": true` (`orca status` is not enough — it succeeds anywhere). No Orca → still run C-1 up to
  and including the approval gate, then tell the user to open Grok Build in this repo and run
  `/team implement <design doc path>`.
- **I am Grok** → [G. Grok-driven](#g-grok-driven-feature-mode-fallback) (the fallback), including the
  `/team implement <design doc path>` entry. Foundation mode is Claude-only: if asked for it, tell the
  user to run `/team foundation …` in Claude Code, and stop.

**When a feature doesn't fit** (checked while designing):
- **Too big for one run** (roughly >30 files or >1 hour of implementation) → split it. With a
  foundation, add the pieces to `slices.md` as new slices; without one, split into sequential feature
  runs, or propose foundation mode if this is really a service being built from scratch.
- **Needs a new expensive-to-reverse decision, or contradicts the foundation** →
  [F-change](#f-change-changing-the-foundation). Claude runs it; Grok stops and hands it to the user.

## Shared rules

Design and code review belong to Claude, code writing belongs to Grok. **A design goes to
implementation only after Grok's adversarial review → Claude's rebuttal/acceptance and revision**
(design review ≤2 rounds per design; code review ≤3 rounds). Commit only when the user asks. Never
run verification that writes to production databases or external services. The user is involved
only at: **the charter questions and gate, the foundation approval, every feature design's approval
gate (mandatory), foundation changes**, and when a business judgment (cost, customer impact,
operating policy) is split. Otherwise don't interrupt them. Write all user-facing output in the
user's language. Scratch files (prompts, reviews) go to `/tmp/team/<slug>/` so git stays clean;
`<slug>` is a short kebab-case name for the task, also used in the design doc filename.

Design quality bar (applies to every design doc, decision record, adversarial review and approval
summary):
1. **Reuse before rewrite.** Inventory what already exists and works (apps, screens, libraries,
   infra) before proposing anything new. A rewrite needs an explicit reason.
2. **Current as of today's date.** For every framework/platform feature adopted, confirm the
   currently recommended approach (load the platform's knowledge-update skill if one exists, check
   docs via context7 / web search) and cite it. Prefer platform primitives (auth, queues, durable
   workflows, cron, rate limiting, observability) over hand-rolled implementations.
3. **Measured, not guessed.** Ground scale and scope in numbers from read-only sources (DB row
   counts, traffic, infra inventory via cloud CLI describe/list). Never write to production. A new
   service with no traffic uses the charter's design caps as its scale evidence.
4. **No over-engineering.** Every component must justify itself against the measured scale (or the
   design caps). The design lists what was deliberately *not* built.

If a source the bar asks for can't be reached (a tool is refused, a service isn't authenticated),
write `not verified: <reason>` in that place. Never guess to fill the gap.

Overall flow:
```
[foundation, once per service]
charter (with the user) → ★ charter OK ★ → decision records + slice map → Grok adversarial review
→ Claude rebut/accept (≤2) → ★ foundation approval ★ → S1, S2, … each as one feature run

[feature, once per slice or task]
Claude design → Grok adversarial review → Claude rebut/accept + revise doc → (re-review ≤2)
→ ★ human approval gate (stop and wait) ★
→ Grok implements → Claude code review → Grok fixes → (re-review ≤3) → report
```

---

## Shared templates

### T1. Design doc contents (feature)
File: `docs/design/<YYYYMMDD>-<slug>.md`. Do not modify source files while designing.
```
- Goal / background (one paragraph)
- Foundation (only if docs/design/foundation/ exists): the slice id (S<n>) this implements, and the
  charter sections / decision records it relies on — cited by path, never restated or re-decided.
- Scope of change: list of files to modify or create (paths)
- Interfaces, schemas, function signatures (concrete enough that the implementer never guesses)
- Step-by-step implementation order
- Definition of done: test commands/conditions that must pass, manual checks
- Do-not-touch: files that must not change, forbidden actions
- Alternatives considered: for each major decision, the simpler option and why it was rejected.
  Evaluate REUSING existing assets (existing apps, screen sets, libraries, infra) before any rewrite.
- Currency check (as of today's date): for each adopted framework/platform feature, the currently
  recommended approach with a citation (platform knowledge-update skill, context7, web). Prefer
  platform primitives (auth, queues, durable workflows, cron, rate limiting) over hand-rolled code.
- Scale evidence: measured numbers from read-only sources (DB counts, traffic, infra inventory).
  Never write to production systems.
- Deliberately not built: what was left out to avoid over-engineering, and why.
```
Method: don't explore for long. **Within 10 minutes, Write the document skeleton first (the headings
above + what you already know), then fill it in with Edit as you investigate.** Do not exceed 40 tool
calls. If this round has a defined implementation slice, detail only that slice and list the rest as
one-liners under a "Follow-ups" section. If the design stops fitting (section 0), stop and report that
instead of writing a bigger doc. A source you can't reach → `not verified: <reason>`.

### T2. Adversarial design review (checklist + output format)
Read the design doc **in full** and verify it against the repository directly. The goal is to
**break** the design. Don't list what you agree with — only problems. Attach evidence to each item
(file:line / observed behavior / RPC or schema contract). Checklist:
- Do the files in the scope actually exist? Is anything missing (call sites, tests, config, types)?
- Do signatures, schemas and RPC response shapes match the real code?
- Regression paths that break existing behavior; migrations, compatibility, rollback
- Is the definition of done actually runnable? Any verification gaps?
- For anything touching payments/DB/customers: double-processing, races, state on failure
- Anything an implementer would have to guess ("I couldn't build this as written")
- **Foundation**: does the design contradict or quietly re-decide the charter or an accepted decision record?
- **Rewrite-vs-reuse**: does the design rebuild something that already exists and works (an app, a
  screen set, a library, a pipeline)? Name the existing asset and what reusing it would save.
- **Stale patterns**: hand-rolled auth / queues / cron / rate limiting / session handling where the
  platform or a standard library provides it as of today; outdated runtime assumptions.
- **Over-engineering**: components, layers or abstractions not justified by the measured scale
  (cite the numbers); anything with exactly one caller.
- **Unmeasured claims**: scope or sizing statements with no read-only measurement behind them. An
  explicit `not verified: <reason>` is not a finding by itself — a decision that depends on it is.

Output format (in G, Grok writes it to `/tmp/team/<slug>/design-review-<N>.md`; in C and F, Grok is
read-only and returns it as `text`, and Claude saves it to that path):
```
## Critical (implementing as written would be wrong or break things) — evidence required
## Missing (needed but absent from the design)
## Ambiguous (things the implementer would have to guess — phrase as questions)
## Verdict: needs revision | ready to implement
```

### T3. Approval gate — always stop before implementing
Once the design is final, **do not start implementing**. Show the user this summary, then **end your
turn and wait for their answer**:
```
## Design finalized — approval requested
- Document: docs/design/….md   (slice S<n>, if there is a foundation)
- One-line summary: …
- Scope: N files (create …, modify …)
- Key decisions (3–5): …
- Adversarial review: Grok raised N items → Claude accepted N (what changed) / rebutted N (why)
  (a review that failed to complete is stated here, not hidden)
- Reuse vs rewrite: what existing assets are reused; what is rebuilt and why
- Currency: key platform/framework choices and the date-stamped source confirming they are current
- Scale evidence: the measured numbers (or design caps) the sizing rests on; what is not verified
- Deliberately not built: …
- Definition of done: <test commands>
- Risks / things you should know: …
Reply "approve" or "go" to proceed. Otherwise tell me what to change.
```
- **"approve" / "go" / "proceed"** → set the slice to `designed` (if there is a foundation), then
  C-2 (Claude-driven: dispatch Grok — Claude never writes the code itself), or the no-Orca hand-off
  (section 0), or G-2.
- **Change requests** → revise the doc, summarize only what changed and show the gate again. A
  substantial change gets a fresh adversarial review (a new ≤2 count) before the gate.
- Never skip this gate. The only exception is when the user's original request explicitly said
  "proceed without approval".

### T4. Code review format
```
## Verdict: APPROVE | REQUEST_CHANGES
## Required changes (file:line, what and how)
## Suggestions (optional)
## Test results
```

### T5. Report
```
## Result
- Design doc: docs/design/….md (Claude draft → Grok adversarial review ×N → Claude revision)
  - What the review changed: … / What Claude rebutted and kept: …
- Slice: S<n> → done (slices.md updated); next: S<m> (todo, dependencies done) — say "go" to start it
- Files changed: … (Grok)
- Code review: N rounds — what the review fixed: …
- Tests: <command> passed
- Cost: Claude $X / Grok $Y (what is known)
## Open issues / decisions for the user
```
Inside Orca, also update the card:
`orca worktree set --worktree active --comment "implemented + reviewed: <feature>" --json`.
Start the next slice only when the user says so.

### T6. Calling Grok for a review (Claude-driven: C-1, F-4, F-change)
Prompt file `/tmp/team/<slug>/<name>-req.md`: the absolute paths to review, the checklist, and the
T2 output format.
```bash
bash ~/.claude/skills/debate/grok-turn.sh /tmp/team/<slug>/<name>-req.md new <max-turns>
```
- `"maxTurns": true` → resume the same `sessionId` with "Stop exploring. Write the review now in the
  required format from what you have." (max-turns 10). Never start over.
- `text` without `## Verdict:` → resume once with "Answer in the required format." Still none → the
  review **failed**: never read that as "no Critical items"; say so at the gate.
- Killed or timed out → the id is in `/tmp/team/<slug>/last-grok-session`; resume it.
- Save each round's `text` to `/tmp/team/<slug>/design-review-<N>.md`.
- Round 2, in the same session, only what changed:
  ```
  Accepted: <item> → doc changed: <where>
  Rebutted: <item> — evidence: <file:line / result>
  Answers: <answers to your questions>
  Re-check the revised doc and answer in the same format with an updated verdict.
  ```

---

## F. Foundation mode

For a service designed from scratch, or a re-founding. **Claude only.** Orca is not required (Grok is
called headlessly, read-only). Output lives in `docs/design/foundation/` and is **canonical**: feature
design docs cite it and never restate or override it. It changes only through F-change.
```
docs/design/foundation/
  charter.md                what the service is — the user's decisions
  decisions/NNN-<slug>.md   one expensive-to-reverse decision each
  slices.md                 the ordered slice map + status
```
Scratch: `/tmp/team/<slug>/` with `<slug>` = `foundation-<service>` (so T6's paths hold as written).

### F-0. Inventory
- A foundation already exists → update it; don't recreate it. A request to change it → F-change.
- Read the existing design docs, code and infra. **One canonical place per decision**: if an existing
  doc already settles something, prefer extracting it into the foundation and leaving a pointer in the
  old doc; never keep two canonical copies. Whether to edit the user's existing docs is one of the F-1
  questions.
- Measure what already exists (read-only): tables and row counts, deployed services, traffic.

### F-1. Charter (the user decides; Claude drafts) → `charter.md`
Sections, 1–2 pages in total:
```
- One line: what the service does, for whom
- Who, and what each does: the core flows, one short paragraph each
- Success / failure: observable signals, not adjectives
- Design caps: the scale the design must hold (users, companies, orders, catalog, regions…) —
  the scale evidence while there is no traffic
- Not doing: explicit non-goals
- Open questions
```
Draft from the request, the existing docs and F-0. **Mark every unknown as a question — don't guess
business decisions.** Ask in batches of up to 4 (AskUserQuestion when available: concrete options,
the recommended one first). Grok does not review the charter — these are product calls, not code.
**Gate: show the charter summary (one line, caps, non-goals, open questions left) and end your turn.**
Go on to F-2 only on "OK" / "approve" / "go"; anything else → revise and show it again. Open questions
that a decision depends on must be answered before that decision is written.

### F-2. Decision records → `decisions/NNN-<slug>.md`
Only decisions that are **expensive to reverse once code or data depend on them**. Check each
candidate and skip what doesn't apply: data model and source of truth (ledger), identity/auth and
account linking, tenancy and permissions, external integrations (channels, payments, carriers),
money and document flow, runtime/deployment and background work (queues, cron, webhooks),
observability. Cheap-to-reverse choices (screen layout, copy, a library used by one screen) belong
in slice designs — leave them out.
```
# NNN <decision title>
Status: proposed | accepted | superseded by NNN | rejected
Context: the charter sections and measured facts this rests on
Decision: …
Options considered: reuse an existing asset / a platform primitive / the simplest option — and why each was rejected
Currency: the currently recommended approach, with a date-stamped source
Consequences: what this commits us to; what gets harder
Revisit when: the observable signal that would make this wrong (tie it to the design caps)
Not built: …
```
Keep each record to about one page. Write every record's skeleton first, then fill them in.

### F-3. Slice map → `slices.md`
- **S1 is a walking skeleton**: the thinnest end-to-end path that exercises every accepted decision
  once and runs in a non-production environment (e.g. inbound event → source-of-truth row → one
  screen → preview deploy). No polish. If that can't fit one run, split it into S1a, S1b… that
  together touch every decision, chained with `depends on` — the size rule wins.
- Then order by risk (the least-proven decision first), then by value.
- Each slice fits **one feature run**: roughly ≤30 files and ≤1 hour of implementation. Split
  anything larger.
- Per slice: goal (one line) / decisions exercised (NNN) / rough scope (modules or directories, not
  file lists) / definition of done / depends on / status.
- Status: `todo` → `designed` (its T3 gate approved) → `done` (T5 reported). `blocked: <reason>` when
  it stops (F-change, design still contested after 2 review rounds, code review not approved after 3);
  back to `designed` when its revised design is approved again.
- Detail S1–S3 only; the rest are one line each.

### F-4. Adversarial review (Grok, headless, read-only)
T6 with max-turns 40 and prompt `/tmp/team/<slug>/foundation-review-req.md`: the absolute
paths of the charter, every decision record and `slices.md`, this checklist, and the T2 output format.
- Contradictions: decision vs charter, decision vs decision, slice vs decision
- Missing expensive decisions (what would hurt to change after S3?); listed decisions that are
  actually cheap to reverse (move them into slices)
- Rewrite vs reuse, stale patterns, over-engineering against the design caps (cite them), unmeasured claims
- Does S1 (or S1a, S1b…) really touch every decision end to end? Is any slice too big for one run?

Check every item against the code and docs **yourself**, then accept (edit the doc) or rebut (with
evidence). ≤2 rounds in the same Grok session. Items still contested after 2 rounds go to the user at
F-5 with both sides' evidence.

### F-5. Foundation approval gate
```
## Foundation ready — approval requested
- Charter: docs/design/foundation/charter.md — one line: …
- Decisions (N): NNN <title> — one line each (+ what Grok's review changed)
- Slices: S1 <walking skeleton> / S2 … / S3 … (+N more, one line each)
- Adversarial review: Grok raised N → Claude accepted N / rebutted N (or: the review failed — why)
- Contested (your call): …
- Open questions: …
Reply "approve" to accept the foundation and start S1. Otherwise tell me what to change.
```
End your turn and wait. Approved ("approve" / "go" / "OK") → set the decision records to `accepted`, then start S1 at **C-1**:
Claude writes S1's design, runs its review and its own T3 gate. (Without Orca, the hand-off to Grok
happens after that gate, as in section 0 — never hand `slices.md` to Grok as a design.)

### F-change. Changing the foundation
Entered two ways: a slice's design, implementation or review shows that a charter line or an accepted
decision is wrong (or needs a new expensive-to-reverse decision), or the user asks for a change
directly (`/team foundation change: …`, possibly handed over from G).
1. **Stop the slice, if one is in progress.** In C with a worker running: reply to its question (or
   `orca terminal send --terminal <assignee_handle> --text "<msg>" --enter --json`) with "Stop: the
   design is changing. Don't edit further; send worker_done with the files modified so far." Wait for
   it as in C-3; once the dispatch has settled, `orca orchestration worker-release --dispatch <ctx_id>
   --json`. If it never settles, leave it running and tell the user — never release on idle (C-5).
   Set the slice to `blocked: <reason>`. A feature design doc never overrides the foundation.
2. Write a new decision record (`proposed`) that supersedes the old one (charter: edit it and add a
   dated change line).
3. T6 review of the change (only the F-4 checklist items the change touches, ≤2 rounds), then show
   the change to the user and end your turn.
4. **Rejected** → set the new record to `rejected`, revert the charter edit, and put the stopped
   slice back to its previous status; ask the user how to proceed with it.
   **Approved** → new record `accepted`, old record `superseded by NNN`. In `slices.md`: update the
   `todo`/`designed` slices it affects; for `done` slices built on the old decision, add a rework slice
   ("S<k>: move S<n> to NNN") instead of reopening them.
5. Resume the stopped slice, if any, as a feature design again: revise its design doc to match,
   starting from what the worktree already contains (list the partial work the stopped worker left),
   run T6 on it (a fresh ≤2 count), then its T3 gate — and continue as T3 says (C-2 with a new task
   spec, or the no-Orca hand-off).

**In G** Grok cannot run this (foundation work is Claude-only, and headless design mode cannot write
`docs/design/foundation/`): stop implementing, set the slice to `blocked: <reason>`, tell the user to
run `/team foundation change: <what and why>` in Claude Code, and stop.

---

## C. Claude-driven feature mode (default)

Claude designs and reviews; Grok is launched as an Orca orchestration worker (a real TUI with
file-edit rights, visible to the user as a tab). Needs an Orca-managed worktree (section 0).
Verified 2026-09-16: `worker-start --agent grok` → Grok followed the injected preamble and replied
with `worker_done`. A full run on 2026-09-21 went through 2 design-review and 3 code-review rounds.

### C-1. Design doc + Grok adversarial review (mandatory)
If `docs/design/foundation/` exists, read the charter, the accepted decisions and `slices.md` first.
The task should be one slice whose dependencies are `done`; if it isn't in `slices.md`, add it as a
slice first (or F-change if it needs a new expensive decision). A dependency not `done` yet → don't
design this slice; tell the user which slice has to come first and stop. Inventory existing assets and measure
scale from read-only sources, then write the design doc (T1). Then the adversarial review: T6 with
max-turns 30, prompt `/tmp/team/<slug>/design-review-req.md` (T2 checklist + T2 output format + the
design doc's absolute path).
Check every Critical/Missing/Ambiguous item **against the code yourself**, then accept (revise the
doc) or rebut (with evidence). If Critical items remain and Grok needs to see the rebuttal, run one
more round in the same Grok session — 2 rounds total. Still contested after 2 → do not implement;
set the slice `blocked` and report both sides to the user. No Critical items left → **the approval
gate (T3)**: end your turn and wait. Do not go to C-2 before approval.

### C-2. Run + Task + Grok worker
```bash
orca orchestration run-create --objective "<feature>" --json
orca orchestration task-create --spec "<spec>" --json                     # → task_id
orca orchestration worker-start --task <task_id> --worktree current --agent grok --timeout-ms 120000 --json
orca orchestration dispatch-show --task <task_id> --json                   # → ctx_… , assignee_handle
orca worktree set --worktree active --comment "grok implementing: <feature>" --json
```
Spec template:
```
Read the design doc first: <absolute path>. Implement all of it, in its implementation order
(or only "<part>" when this task is one of several parallel chunks).
Definition of done: <test commands/conditions>. Include the passing results in the worker_done body.
Rules: do not modify files outside the doc's "scope of change". If you believe the design must be
deviated from, ask before implementing. Do not commit. On completion pass every modified file in
worker_done --files-modified.
```
Default: one Task = one Grok, same worktree. Parallelize only for independent chunks whose files
don't overlap.

### C-3. Wait + answer questions
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
prompt asks for). If Grok's question means the design must change, revise the doc before answering;
a foundation-level change → F-change (it starts by stopping the worker). While Grok is dispatched,
Claude does not edit source files.

### C-4. Review
`git diff` + **re-run the definition-of-done tests yourself**, judged against the design doc (T4).
Changes needed → reuse the same Grok:
```bash
orca orchestration task-create --spec "Apply review: <per-item instructions, file:line>" --json
orca orchestration worker-start --task <new_task_id> --terminal <assignee_handle> --json
```
→ C-3. At most 3 rounds. Still not approved after 3 → set the slice `blocked`, report the remaining
items and both sides' reasoning to the user, and still do the C-5 cleanup.

### C-5. Wrap up
```bash
orca orchestration worker-release --dispatch <ctx_id> --json     # for every completed dispatch
orca orchestration check --ack <deliveryId> --json
orca worktree set --worktree active --comment "implemented + reviewed: <feature>" --json   # failure path: "blocked: <reason>"
```
If there is a foundation and the review approved, set the slice to `done` in `slices.md`. Report with
T5. Never stop/release a worker because of a timeout or idle state. If a handle returns
`terminal_handle_stale`, re-acquire it with `orca terminal list --worktree active --json`; never send
to both old and new handles.

---

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
  writes through the shell are refused. Web search is refused in this headless mode (context7 worked
  in a real run); anything refused ends up as `not verified` (T1).
- `review`: Read + Bash (to run tests). Write/Edit and mutating Bash (git commit/checkout/reset,
  rm, mv, sed -i, …) are blocked.
- Allow rules in the user's own Claude Code settings still apply in both modes.
- The script `cd`s to the repository root itself, so it works from any directory.
- Always pass prompts as files (avoids shell quoting), in `/tmp/team/<slug>/`.
- If the result's `subtype` is `error_max_turns` (the script exits 1 then, but the line still has
  `subtype` and `sessionId`), or `text` lacks the expected marker (`DESIGN_DOC:` / `## Verdict:`),
  resume **the same sessionId** once with "continue and finish". Never start a new session for that.
- Roughly $0.3–2 per call. **A large design takes 20–40 minutes.** If Grok's Task/background tool
  has a kill deadline, disable it or set it generously (60 min+). Killing at 25 minutes throws away
  all exploration done so far.
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
Follow the design doc's scope, signatures and order exactly. Never modify files outside the scope.
If you conclude the design must be deviated from, ask Claude before implementing that part (the
Claude session, `design` mode — so a changed decision lands in the doc; Claude can't touch source
anyway). Do not implement that part until you have the answer. If the answer is that the change
contradicts the foundation or needs a new expensive decision → F-change (the "In G" paragraph). Run
the definition-of-done tests yourself and make them pass. Do not commit.

### G-3. Code review request → `team-review.md` (resume the Claude session)
```
Role: reviewer. Check whether the implementation matches the design doc: <path>.
Inspect the change with git diff and git status, and run the definition-of-done tests yourself (do not modify files).
Check: omissions/additions vs the design, scope violations, test results, regression risk, existing code conventions (minimal change).
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
