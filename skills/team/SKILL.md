---
name: team
description: >-
  Cross-model agent team: Claude designs and reviews, Grok implements (UI and front-end work goes to a
  Claude Sonnet worker). Feature mode (default): Claude
  drafts the design -> a Claude reviewer subagent and Grok attack it in parallel -> Claude revises ->
  human approves -> Grok (Sonnet for UI chunks) implements as an Orca worker (or Claude, if the user
  asks) -> a Claude reviewer subagent reviews the code, plus a ponytail over-engineering pass (ponytail is mandatory in
  both tools). Foundation mode ("/team foundation
  <service>"): for a service designed from scratch or re-founded - Claude drafts the charter with the
  user, the expensive-to-reverse decisions and a slice map, Grok attacks them, the human approves,
  then every slice runs through feature mode. Run it from Claude Code (the default). From Grok Build,
  "/team <task>" still works as the fallback: Grok calls Claude headlessly for design and review and
  implements itself. Triggers: "/team", "/team foundation", "have grok implement this", "design then
  let grok code", "work as a team", "like Agent Teams", "design the whole service from scratch".
  Trivial edits (1-2 files) don't need a team - just do them.
argument-hint: "[foundation|implement] [--reviewer both|claude|grok] [--implementer grok|sonnet] <feature, task, service or design doc>"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# /team — Claude designs and reviews, Grok implements

This skill is loaded by both Claude Code and Grok Build. First pick the mode, then the path.
Foundation mode and the Grok-driven path live in their own files next to this one; read a file only
when its path is taken.

## 0. Mode and path

**Mode** (from the request):
- **Foundation** — `/team foundation …`, or the request is a new service built from scratch, or a
  re-founding that changes several expensive-to-reverse decisions at once, or a change to an existing
  foundation → F: read `~/.claude/skills/team/foundation.md` and follow it
- **Feature** — everything else: one change set that fits one implementation run → feature mode

**Path** (from who is executing):
- **I am Claude** → foundation: F (`foundation.md`). Feature: **[C. Claude-driven](#c-claude-driven-feature-mode-default)
  (the default)**. C needs this worktree to be Orca-managed: `orca worktree current --json` returns
  `"ok": true` (`orca status` is not enough — it succeeds anywhere). No Orca → still run C-1 up to
  and including the approval gate, then tell the user to open Grok Build in this repo and run
  `/team implement <design doc path>` (implementer `sonnet`: open `claude --model sonnet` in this repo,
  have it implement the design doc in its order and scope without committing, then come back here
  for C-4).
- **I am Grok** → G, the fallback: read `~/.claude/skills/team/grok-driven.md` and follow it, including
  the `/team implement <design doc path>` entry. Foundation mode is Claude-only: if asked for it, tell the
  user to run `/team foundation …` in Claude Code, and stop.

**When a feature doesn't fit** (checked while designing):
- **Too big for one run** (roughly >30 files or >1 hour of implementation) → split it. With a
  foundation, add the pieces to `slices.md` as new slices; without one, split into sequential feature
  runs, or propose foundation mode if this is really a service being built from scratch.
- **Needs a new expensive-to-reverse decision, or contradicts the foundation** → F-change
  (`foundation.md`). Claude runs it; Grok stops and hands it to the user.

## Shared rules

Design and code review belong to Claude, code writing belongs to Grok — UI work to a Claude Sonnet
worker ([implementer routing](#implementer-routing)) — unless the user asks Claude to implement (C-2).
**A design goes to implementation only after the adversarial review (T6: a Claude
reviewer subagent and Grok in parallel) → Claude's rebuttal/acceptance and revision** (design review
≤2 rounds per design; code review ≤3 rounds). Commit only when the user asks. Never
run verification that writes to production databases or external services. The user is involved
only at: **the charter questions and gate, the foundation approval, every feature design's approval
gate (mandatory), foundation changes**, and when a business judgment (cost, customer impact,
operating policy) is split. Otherwise don't interrupt them. Write all user-facing output in the
user's language. Scratch files (prompts, reviews) go to `/tmp/team/<slug>/` so git stays clean;
`<slug>` is a short kebab-case name for the task, also used in the design doc filename.

**[ponytail](https://github.com/DietrichGebert/ponytail) is mandatory.** Preflight, before any design
work: `ponytail:ponytail-review` is in Claude Code's skill list, and `grok plugin list` shows
`ponytail` (Grok keeps plugins off until `grok plugin enable ponytail`). Either missing → stop and
give the user the install commands (`/plugin install ponytail@ponytail`; `grok plugin install
DietrichGebert/ponytail --trust` + `grok plugin enable ponytail`). If ponytail's always-on mode is off
in this session, load the `ponytail` skill through the Skill tool before designing.
- **Ponytail decides what gets built and how the code is written**: its ladder (needed at all? →
  reuse → stdlib → native → installed dependency → one line → minimum code) applies to every component
  a design proposes and every line the implementer writes.
- **Team rules decide the process and the documents, and win where the two conflict**: every T1
  section and every review/report format is explicitly requested ("no design notes" doesn't apply to
  them); the approval gates are never defaulted past ("never stall on a default" doesn't apply to
  them); the implementer builds everything the design specifies — a cut it wants is a question (C-3)
  or a review item, never a silent omission.
- Claude Code runs ponytail through its hooks — subagents and Sonnet workers included. Grok Build has
  no such hook, so the worker spec tells the implementer to use the `ponytail` skill (C-2, G-2).
- Never type `/ponytail…`, "stop ponytail" or "normal mode" as a prompt during a run — they flip
  ponytail's global mode flag for every session. Invoke its skills through the Skill tool.
- The `ponytail-review` over-engineering pass runs in every code review (C-4, G-3).

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
4. **No over-engineering.** Every component must pass ponytail's ladder and justify itself against
   the measured scale (or the design caps). The design lists what was deliberately *not* built.

If a source the bar asks for can't be reached (a tool is refused, a service isn't authenticated),
write `not verified: <reason>` in that place. Never guess to fill the gap.

### Implementer routing
In Claude-driven runs (C), the design doc names who writes each chunk (T1 `Implementer:`):
- **`sonnet`**: UI work. That covers visual design, front-end screens, components, styles, templates
  and UI copy. It runs as a Claude Code Orca worker, `--agent claude --model sonnet`. Pass the alias,
  not a pinned id, so it follows the newest Sonnet.
- **`grok`**: everything else (the default).
- A feature with both: split it into chunks whose files don't overlap (C-2), fix the contract between
  them (API shape, props, routes) in the design doc, and start one worker per chunk in parallel.
- `--implementer grok|sonnet` in the request overrides the routing for the whole run; "you implement
  it" still means Claude itself (C-2).
- Sonnet runs as an Orca worker rather than a subagent so that it goes through the same task →
  question → `worker_done` → "Apply review" loop as Grok, in a tab the user can watch and step into.
- A Sonnet chunk is reviewed by the Claude reviewer, which is the same model family, so C-4 also
  runs the Grok code review on it (non-blocking) to keep a different model in the loop.

In G (Grok-driven), Grok implements everything; this routing doesn't apply.

Overall flow:
```
[foundation, once per service]
charter (with the user) → ★ charter OK ★ → decision records + slice map → adversarial review (T6)
→ Claude rebut/accept (≤2) → ★ foundation approval ★ → S1, S2, … each as one feature run

[feature, once per slice or task]
Claude design → adversarial review (T6: Claude reviewer ∥ Grok; wait for Claude only)
→ Claude rebut/accept + revise doc → (re-review ≤2)
→ ★ human approval gate (stop and wait) — Grok's late result is merged here ★
→ Grok implements with ponytail (UI chunks: Sonnet; or Claude, if asked) → Claude reviewer subagent
  code review + ponytail-review → fixes (≤3) → report
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
- Implementer: `grok` | `sonnet` (implementer routing). Split between both → the files each chunk
  owns and the contract between the chunks.
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
instead of writing a bigger doc. A source you can't reach → `not verified: <reason>`. Ponytail shapes
what the design proposes, not the document: every section above is requested, so write each in full.

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

Output format (in G, Grok writes it to `/tmp/team/<slug>/design-review-<N>.md`; in C and F, both
reviewers are read-only and return it as text, and Claude saves each to
`/tmp/team/<slug>/<name>-<reviewer>-<N>.md`):
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
- Implementer: grok | sonnet (per chunk, if split)
- Key decisions (3–5): …
- Adversarial review: Claude reviewer raised N / Grok raised M (or: still running — merged when it
  arrives, see T6) → Claude accepted N (what changed) / rebutted N (why)
  (a review that failed or timed out is stated here, not hidden)
- Reuse vs rewrite: what existing assets are reused; what is rebuilt and why
- Currency: key platform/framework choices and the date-stamped source confirming they are current
- Scale evidence: the measured numbers (or design caps) the sizing rests on; what is not verified
- Deliberately not built: …
- Definition of done: <test commands>
- Risks / things you should know: …
Reply "approve" or "go" to proceed. Otherwise tell me what to change.
```
- **"approve" / "go" / "proceed"** → set the slice to `designed` (if there is a foundation), then
  C-2 (Claude-driven: dispatch the implementer workers; Claude writes the code itself only if the
  user asked for that),
  or the no-Orca hand-off (section 0), or G-2.
- **Change requests** → revise the doc, summarize only what changed and show the gate again. A
  substantial change gets a fresh adversarial review (a new ≤2 count) before the gate.
- Never skip this gate. The only exception is when the user's original request explicitly said
  "proceed without approval".

### T4. Code review format
```
## Verdict: APPROVE | REQUEST_CHANGES
## Spec check — quote the design doc line for each item
- Missing or partial: …
- Not asked for (scope creep): …
- Implemented but looks wrong: …
## Required changes (file:line, what and how)
## Suggestions (optional)
## Test results (each command you ran and its output: pass/fail counts, exit code)
```

### T5. Report
```
## Result
- Design doc: docs/design/….md (Claude draft → adversarial review ×N (Claude reviewer / Grok) → Claude revision)
  - What the review changed: … / What Claude rebutted and kept: …
- Slice: S<n> → done (slices.md updated); next: S<m> (todo, dependencies done) — say "go" to start it
- Files changed: … (Grok / Sonnet per chunk, or Claude if the user asked)
- Code review: N rounds (Claude reviewer subagent; Grok too with --reviewer grok|both or on Sonnet chunks) — what it fixed: …
- Over-engineering pass (ponytail-review): N suggested → N applied (net −N lines), N rejected (why)
- Tests: <command> → the output of Claude's own run after the last fix (N passed, 0 failed, exit 0);
  never "should pass" or the worker's word
- Cost and time: Grok USD per call and minutes per review; Claude reviewer minutes (what is known)
## Open issues / decisions for the user
```
Inside Orca, also update the card:
`orca worktree set --worktree active --comment "implemented + reviewed: <feature>" --json`.
Start the next slice only when the user says so.

### T6. Adversarial review — Claude reviewer and Grok in parallel (C-1, F-4, F-change)
Grok alone took 19–21 minutes per design review in a real run (2026-09-23), and each time it caught
Critical items the designer had missed; a same-model reviewer misses different things than a
different model does. So both run, at the same moment, and only the Claude reviewer blocks.

**Reviewer choice** (`--reviewer` in the request; default `both`):
- `both` — Claude reviewer subagent + Grok, in parallel (default for design and foundation reviews)
- `claude` — the subagent only (fast; no cross-model view — say so at the gate)
- `grok` — Grok only (the old behaviour; the gate waits for it)

**1. One request file, two reviewers.** Write `/tmp/team/<slug>/<name>-req.md` once: the absolute
paths to review, every fact you already measured (so neither reviewer spends turns re-deriving it),
the checklist, and the T2 output format. Then, in the same message:
- **Claude reviewer**: the Agent tool with `subagent_type: "team-reviewer"`
  (`~/.claude/agents/team-reviewer.md`: read-only, loads CLAUDE.md, returns an agent ID so round 2 can
  resume it; missing → `general-purpose` with the same read-only instruction). Never `Plan`: it is
  one-shot (no agent ID) and skips CLAUDE.md. Subagents run in the background by default; the Agent
  tool no longer takes `run_in_background`. Prompt = the request file's contents plus: "Review only;
  do not edit files. Do not touch databases or external services (no MCP write tools, no integration
  tests that write, no deploys)." It starts with a fresh context, so the prompt must be self-contained.
- **Grok**: Bash with `run_in_background: true` and `timeout: 3600000` (background commands stop at
  their timeout, 30 min by default, and a Grok review takes ~20 min before any resume; resumes use
  the same settings):
  ```bash
  bash ~/.claude/skills/debate/grok-turn.sh /tmp/team/<slug>/<name>-req.md new 20
  ```
  Grok runs headless read-only (verified 2026-10-01): read-only shell commands (git diff/log/show,
  grep, rg, cat, ls) work and its edit tools are removed, but **any write attempt cancels its turn**
  (`stopReason: "cancelled"`). The request file must say: "Read-only commands only; never write files
  or redirect output."

**2. Wait for the Claude reviewer only.** When it returns: check every item against the code
yourself, accept (edit the doc) or rebut (with evidence), then go on (to the gate, or round 2).

**3. Grok's result, whenever it lands** (you are notified; never poll):
- Before the gate is shown → merge it like the Claude reviewer's items.
- While the gate is waiting for the user → check its items, apply accepted ones to the doc, and post a
  short update (what it found, what changed). A newly accepted Critical that changes the design
  substantially → show the gate again.
- After approval → an accepted Critical pauses the affected work and goes to the user; everything
  else is folded into the code review.
- Grok's handling: `"maxTurns": true` → resume the same `sessionId` with "Stop exploring.
  Write the review now in the required format from what you have." (max-turns 10). `stopReason:
  "cancelled"` or `text` without `## Verdict:` → resume once with "Read-only commands only. Answer
  in the required format." Killed → the id is in `/tmp/team/<slug>/last-grok-session`; resume it.
  Still nothing → Grok's review **failed**; say so at the gate (never read it as "no Critical items").

**4. Round 2** (≤2 total) goes only to the reviewer whose Critical you rebutted and who needs to see
the rebuttal — the Claude reviewer via SendMessage to the same agent, Grok by resuming its session:
```
Accepted: <item> → doc changed: <where>
Rebutted: <item> — evidence: <file:line / result>
Answers: <answers to your questions>
Re-check the revised doc and answer in the same format with an updated verdict.
```

Save each reviewer's text to `/tmp/team/<slug>/<name>-<claude|grok>-<N>.md`.

---

## C. Claude-driven feature mode (default)

Claude designs and reviews; the implementer (Grok, or Sonnet for UI chunks) is launched as an Orca
orchestration worker (a real TUI with file-edit rights, visible to the user as a tab). Needs an
Orca-managed worktree (section 0) — except when the user asks Claude to implement (C-2).
Verified 2026-09-16: `worker-start --agent grok` → Grok followed the injected preamble and replied
with `worker_done`. A full run on 2026-09-21 went through 2 design-review and 3 code-review rounds.
Verified 2026-10-01 (Orca 1.4.204, Claude Code 2.1.286): `worker-start --agent claude --model sonnet`
→ the worker came up as Sonnet 5.5, implemented a UI chunk from the design doc and replied with
`worker_done`.
Orca commands below follow Orca's bundled guide (`orca skills get orchestration`, Orca 1.4.215+;
1.4.217 fixed stale worker handles — update through the Orca app, not brew). Where a flag here and
that guide disagree on your version, the guide wins.

### C-1. Design doc + adversarial review (T6, mandatory)
If `docs/design/foundation/` exists, read the charter, the accepted decisions and `slices.md` first.
The task should be one slice whose dependencies are `done`; if it isn't in `slices.md`, add it as a
slice first (or F-change if it needs a new expensive decision). A dependency not `done` yet → don't
design this slice; tell the user which slice has to come first and stop. Inventory existing assets and measure
scale from read-only sources, then write the design doc (T1). Then the adversarial review: T6 with
the request `/tmp/team/<slug>/design-review-req.md` (T2 checklist + T2 output format + the design
doc's absolute path + the facts you measured).
Check every Critical/Missing/Ambiguous item **against the code yourself**, then accept (revise the
doc) or rebut (with evidence). If Critical items remain and a reviewer needs to see the rebuttal, run
one more round (T6 step 4) — 2 rounds total. Still contested after 2 → do not implement;
set the slice `blocked` and report both sides to the user. No Critical items left → **the approval
gate (T3)**: end your turn and wait. Do not go to C-2 before approval.

### C-2. Run + Task + implementer worker
**The user asked Claude to implement** ("너가 직접 구현해", "you implement it") → skip the Orca run,
the worker and C-3: Claude implements the design itself, in its order and scope, runs the definition
of done, then goes to C-4 (the reviewer subagent reviews Claude's diff the same way). Steps the design
reserves for after the code review (applying a migration, deploying, changing platform settings) still
wait for C-4's APPROVE-or-fixed. Otherwise:
```bash
orca status --json
orca orchestration run-create --objective "<feature>" --json               # → run_id
orca orchestration worker-start --spec "<spec>" --worktree current --agent grok --timeout-ms 120000 --json
#   implementer sonnet: --agent claude --model sonnet instead of --agent grok
#   one call creates the Task and its Dispatch (ctx_…); give this Bash call timeout ≥180000
orca orchestration worker-show --dispatch <ctx_id> --json                  # → the worker's terminal handle
orca worktree set --worktree active --comment "<grok|sonnet> implementing: <feature>" --json
```
`worker-start` exits non-zero → don't relaunch: read the receipt's `failedStage` and
`residualResources`, then `orca skills get orchestration --reference references/recovery-and-cleanup.md`.

For a Sonnet worker, check the model on the worker's screen
(`orca terminal read --terminal <handle> --screen --json`, which shows e.g. "Sonnet 5.5"). The
receipt's `launch.effective` only echoes the alias. If it isn't a Sonnet model, stop and tell the
user before any code is written.

A Claude worker started in a folder Claude Code hasn't trusted yet stops at the folder-trust prompt.
In Claude Code 2.1.286 that prompt defaults to "No, exit", so the Enter that comes with the injected
prompt makes the worker exit. `--worktree current` is already trusted because the driver runs there.
For any other placement, have the user open `claude` there once and accept the prompt before
starting the worker.

Spec template:
```
Read the design doc first: <absolute path>. Implement all of it, in its implementation order
(or only "<part>" when this task is one of several parallel chunks).
Definition of done: <test commands/conditions>. Include the passing results in the worker_done body.
Rules: do not modify files outside the doc's "scope of change". If you believe the design must be
deviated from, ask before implementing — with the preamble's `ask` command, never a local question
prompt — and don't enter plan mode. Do not commit. On completion pass every modified file in
worker_done --files-modified.
Ponytail: load the `ponytail` skill (full) before writing code and follow it for how you write it.
The design doc and these rules win where they conflict: build everything the design specifies; if
ponytail says a part should be cut, ask instead of dropping it.
```
A Sonnet worker already runs ponytail through Claude Code's hooks; the line matters for Grok, which
has none.

Default: one Task = one worker, same worktree. Parallelize only for independent chunks whose files
don't overlap, for example a Grok chunk and a Sonnet chunk of the same feature.

### C-3. Wait + answer questions
```bash
orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 540000 --json
orca orchestration reply --id <msg_id> --body "<answer>" --json               # for question
orca orchestration check --ack <deliveryId> --wait --types worker_done,escalation,question --timeout-ms 540000 --json
```
Give each wait Bash `timeout: 600000`: Claude Code stops a foreground command at 10 minutes, so
`--timeout-ms` stays ≤540000 and you simply wait again. Timeouts, `count: 0` and heartbeats are not
failures (implementation takes 15–60 min). `check` replays the oldest batch until it is acked:
process every message in it before `--ack`, and accept a `worker_done` only from the Dispatch you are
waiting for (an earlier one is stale; ignore it). Progress: `worker-read --dispatch <ctx_id> --limit
50 --json`. **After three empty waits in a row**, inspect instead of waiting blindly:
`orca orchestration worker-list --run <run_id> --include-remote --json` (act on each row's
`projection.nextAction`) and `orca orchestration worker-show --dispatch <ctx_id> --json` — a non-null
`observation.agentWait` names a prompt only a human can answer (plan-mode entry, a question card),
with its evidence; answer it with `orca terminal send --terminal <handle> --text "<key>" --enter
--json`. A null or absent `agentWait`, or quiet output, is not a stall: keep waiting. (Orca already
launches both Grok and Claude workers with auto-approve, so edit approvals should not block them.)
If the worker's question means the design must change, revise the doc before answering; a
foundation-level change → F-change (it starts by stopping the worker). While a worker is dispatched,
Claude does not edit source files.

### C-4. Review
Two parts, started together:
- **Reviewer subagent** (default): the Agent tool, `subagent_type: "team-reviewer"` (as in T6), a
  self-contained prompt — worktree path, design doc path, the changed files, the facts measured so
  far, what to check hard (anything that writes to shared state first), and T4 as the output format,
  including its Spec check (every doc requirement missing or partial, behaviour the doc didn't ask
  for, what looks implemented but wrong — each quoting the doc's line); plus "review only; no DB/MCP
  writes, no deploys, no integration tests that write". Measured 2026-09-23: 12.5 minutes, and it
  caught items Grok missed (and vice versa).
- **Claude itself — evidence before claims**: the worker's `worker_done` is a claim, not evidence. Check
  `git diff --stat` against the files it reported and the doc's scope, **re-run every
  definition-of-done command yourself** and read the full output (exit code, failure count), and judge
  the change against the design doc line by line (T4). Report only what that output shows.
- `--reviewer grok|both`, or any chunk Sonnet implemented → also T6-style Grok code review on the
  same request (non-blocking unless `grok`). It can run `git diff` itself (read-only commands only).

**Over-engineering pass (mandatory).** After the correctness review, invoke `ponytail:ponytail-review`
through the Skill tool on the same diff (never as a typed prompt — Shared rules). If it fails, T5 says
so; never report a failed pass as "lean already". It returns a delete-list only (`delete:` /
`stdlib:` / `native:` / `yagni:` / `shrink:` per line). Judge each item like any finding: accept it
only if it keeps the design's interfaces, the definition of done and the things ponytail itself never
cuts (trust-boundary validation, data-loss handling, security,
accessibility). An accepted item that changes an interface in the design doc → revise the doc first
(show T3 again if it is substantial). Merge accepted items into the same "Apply review" spec; they
count toward the same ≤3 rounds.

Changes needed → reuse the worker that wrote the chunk, Grok or Sonnet (or, if Claude implemented,
Claude applies them and the reviewer subagent re-checks via SendMessage). Decide the reuse before acking the old delivery:
```bash
orca orchestration worker-show --dispatch <ctx_id> --json                  # the settled worker's handle
orca orchestration worker-start --spec "Apply review: <per-item instructions, file:line>" --terminal <handle> --worktree current --json
orca orchestration check --ack <deliveryId> --json                         # then wait on the NEW dispatch
```
→ C-3. At most 3 rounds. Still not approved after 3 → set the slice `blocked`, report the remaining
items and both sides' reasoning to the user, and still do the C-5 cleanup.

### C-5. Wrap up
```bash
orca orchestration worker-release --dispatch <ctx_id> --json     # every settled dispatch you are not reusing
orca orchestration check --ack <deliveryId> --json
orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json   # must return none before you end
orca worktree set --worktree active --comment "implemented + reviewed: <feature>" --json   # failure path: "blocked: <reason>"
```
If there is a foundation and the review approved, set the slice to `done` in `slices.md`. Report with
T5. Never stop/release a worker because of a timeout or idle state. If a handle returns
`terminal_handle_stale`, re-acquire it with `orca orchestration worker-show --dispatch <ctx_id>
--json`; never send to both old and new handles.
