---
name: team
description: >-
  Agent team workflow for Gemini CLI (and Orca IDE): the coordinator plans the product, designs and
  reviews, an Orca worker builds (defaults to Gemini CLI so zero Claude tokens are used, or another
  agent the user names). Feature: product plan (when users see the change) -> design doc ->
  independent read-only review (+ a risk reviewer for money, auth and, except before launch,
  data-changing migrations) -> user approval -> the worker implements -> code review +
  ponytail-review -> report. Founded services build a milestone at a time: one
  milestone design, one review, one approval, then its slices back to back and one review of the
  whole milestone alongside its full test suites. Foundation mode ("/team
  foundation <service>") drafts the charter, the expensive-to-reverse decisions and the milestone
  map with the user. Triggers: "/team", "team", "/team foundation", "/team M3" (a milestone or
  slice), "design then have a worker implement it", "implement with gemini", "work as a team",
  "design the whole service from scratch". Trivial edits (1-2 files) don't need a team - just do
  them.
---

# /team — Coordinator plans, designs and reviews, an Orca worker builds

Write to the user in their language (Korean if they write Korean), including template headings; this
file, its templates, Orca notices and subagent results being in English changes nothing. Write every
subagent prompt (survey, reviewers) and worker spec in the user's language and ask for the answer in
it, keeping template headings such as `## Verdict:` as written: English results are what pull the
replies into English.

## Route
- `/team foundation …`, a new service, or a re-founding → `foundation.md` "Found".
- `docs/design/foundation/` exists and the request names a milestone or slice → `foundation.md`
  "Milestone run". A request that changes the foundation → `foundation.md` "Change".
- Anything else → **Feature** below (in a founded repo it reads the charter, accepted decisions and
  `slices.md` first; the product plan and the design cite them and never override them).
(`foundation.md` is next to this file; read it only for those routes.)

## Rules
- **Roles.** The coordinator (Gemini) plans the product (next rule), designs, reviews and decides; an
  Orca worker writes the code (below): **Gemini CLI (`--agent gemini`, no `--model` flag)** by
  default so zero Claude tokens are consumed, unless the user explicitly names another Orca agent
  (e.g. `"claude로 구현해"`, `"implement with sonnet"` → `--agent claude --model sonnet`) in the
  request or at the gate — it holds for that feature or milestone run. No Orca → the user runs the
  spec in their agent. "You implement it" / "직접 구현해" → the coordinator implements directly.
- **Product plan.** A change to what users see or do is planned before it is designed (template P),
  once the survey is in: flows, policies and edge cases, what isn't built, open business questions,
  how other products do it — no files, APIs or schemas yet (the design does those). Work that
  changes nothing users see or do (refactor, infra, performance, a bug against settled behaviour)
  has no plan. Never decide a business call yourself: make it a question. Up to 4 open questions
  that most change the design go to the user before the design doc (`ask_user`, recommended option
  first); the rest take your recommendation and go on the gate as assumptions (a charter asks them
  all: `foundation.md` Found).
- **Approve before code.** Nothing is implemented until the user approves the design (or milestone).
  Only an explicit "proceed without approval" / "승인 없이 진행" in the request skips the gate.
- **Independent review.** Every design and every diff is reviewed by a read-only `team-reviewer`
  subagent via `invoke_agent(agent_name="team-reviewer", prompt="...")`. A **risk reviewer** (a second
  parallel `invoke_agent(agent_name="team-reviewer", ...)` call) joins in parallel for money,
  auth/permissions, every foundation review, and — except before launch (below) — migrations that
  change or drop existing data and customer data; a project's foundation may name more. Every review
  prompt is self-contained (paths, measured facts, the template) and ends with: "Review only: no
  edits, no DB/MCP writes, no deploys, no tests (the coordinator runs them). Stop after 30 tool calls (60
  for a milestone design review, the milestone review or a foundation review) and list what you
  didn't check." Wait for every reviewer you started, then check each finding against the code
  yourself; accept, rebut with evidence, or defer (Deferring a finding).
- **Round 2 reviews in Gemini CLI:** Because `invoke_agent` starts a fresh subagent context each call,
  when running Round 2 for a reviewer, pass a self-contained prompt that includes the design doc/diff
  path, the Round 1 findings, and:
  `Accepted: … → changed: … / Rebutted: … — evidence: … / Deferred: … — why: … / Re-check only what changed and answer in the same format.`
- **Preflight**, once before the survey:
  - Ensure `ponytail-review` is available in `<available_skills>` (activate with
    `activate_skill(name="ponytail-review")` when needed).
  - Check if the project uses an MCP server (e.g. Supabase/Postgres in `.gemini/settings.json` or
    `.mcp.json`). If a required project database MCP is disconnected or needs authentication, ask the
    user to run `/mcp auth <server>`, end your turn, and continue when they say it's done. Never work
    around a disconnected project DB MCP with guesses; if not installed or unreachable, state so once
    and write `not verified: <reason>` where it would have been used.
- **ponytail is mandatory.** The design reviewer applies its ladder to every component;
  `ponytail-review` runs on every diff (activate via `activate_skill(name="ponytail-review")` and
  apply its rules to the diff). Where ponytail and these rules clash, these rules win: documents are
  written in full, gates are never skipped, the worker asks before cutting anything the design
  specifies.
- **Rounds**: design review ≤2 and code review ≤2 — round 1 is the first review, round 2 re-checks
  only what changed. Still contested or not approved after round 2 → stop and report both sides.
- **A design change after review** → revise the doc. A gate edit, a worker question or an accepted
  `ponytail-review` item that changes an interface: one review round on that change. A review finding
  that the design itself is wrong: the fix follows the revised line and the reviewer that raised it
  checks both in its round 2. A substantial change shows the gate again.
- **Deferring a finding** depends on the harm it can cause, never on slice or file boundaries ("this
  slice doesn't touch the database"). One that can lose real data (not test data) or money, do
  something that can't be undone, cut someone off, or show a real person something false is fixed in
  this run — its own fix round, or in a milestone the milestone review's fix (`foundation.md` Build)
  — and a business call in it goes to the user. Every deferral goes under `Deferred` in the design doc
  with its reason; one held for the milestone review's fix is marked `→ milestone fix`. A deferred
  Critical or required change is named in round 2 like a rebuttal; a review whose only open items
  are deferred counts as approved once its round 2 doesn't contest a deferral.
- **Parallel where it pays**: survey with parallel `codebase_investigator` or `generalist` subagents
  per area; independent slices build in parallel, each in its own worktree; a large diff gets one
  reviewer per area. Survey agents find and quote; the coordinator decides.
- **Tests: narrow per change, full once** (how often and how widely tests run is how the team works).
  - A definition of done names the tests covering the change — lint, types, and the unit, integration
    and e2e tests it touches. The worker runs it once at the end, the coordinator once in review; a
    fix round re-runs only what failed and what covers the files it changed. A command that needs a
    post-review step (a migration applied) is marked `after <step>` and runs right after that step.
  - The full suites — every test command the project has, lint and types included, or `none` — are
    listed once in the design and run once by the coordinator: when the code review approves a
    feature, or at the end of a milestone run.
  - Repeated runs ("3 times in a row") only for a test the design notes as flaky, citing the run that
    showed it. A suite that can't run part of itself (the design proposes a filter) runs once at the
    end of a change that edits it, otherwise only with the full suites.
  - A failure in the full suites or an `after` command: a test that exists on the base commit and
    fails there too, or passes on one re-run without being touched by this work, is reported, not
    fixed. Otherwise one fix round (the worker of the slice it's in if still running, else a new one
    in that worktree), code review on the fix, then re-run what failed (after any post-review step
    the fix needs); a milestone commits the fix, a feature leaves it uncommitted with the rest. Still
    failing → stop and report.
- **Before launch** (charter `Stage: pre-launch`; no charter → not before launch) the database holds
  test data: the coordinator and workers may write to it to verify (reviewers stay read-only).
  Otherwise never write to production databases to verify.
- Messages, payments and paid APIs are never used to verify. A source you can't reach → write `not
  verified: <reason>`, never a guess. Post-review steps (applying a migration, deploying) wait for the
  code review's approval. Commit only when the user asks (a milestone approval covers its per-slice
  local commits, their fix commits and the milestone review's fix). Scratch files go to
  `/tmp/team/<slug>/`.

## Feature
1. **Survey** (≤10 minutes): existing assets, call sites, measured scale from read-only sources.
   Broad codebase → parallel `codebase_investigator` / `generalist` subagents, one per area. If the
   design picks something new (a tool, service, library or approach), search today's options for it on
   the web (`google_web_search` / `web_fetch`): the model's memory has gaps even before its cutoff, so
   the choice rests on what was found, not what was recalled. Then, when users see the change, the
   product plan (Rules): template P from what the survey found, then its open questions.
2. **Design doc** `docs/design/<YYYYMMDD>-<slug>.md` (template D). Skeleton first, then fill in.
3. **Design review** (template R): write `/tmp/team/<slug>/<name>-req.md` (paths, measured facts,
   template R) and start the `team-reviewer` subagent (+ risk reviewer if applicable) in parallel via
   `invoke_agent(agent_name="team-reviewer", prompt="...")`. Round 2 goes only to a reviewer whose
   Critical you rebutted or deferred: invoke `team-reviewer` with the Round 1 context plus "Accepted:
   … → changed: … / Rebutted: … — evidence: … / Deferred: … — why: … / Re-check and answer in the
   same format."
4. **Gate** (template G): show it, end your turn, wait.
5. **Build**: the worker with the spec (template S). The coordinator doesn't edit source meanwhile. A
   worker question that changes the design → revise the doc before answering (foundation-level →
   `foundation.md` "Change").
6. **Code review**, together: `invoke_agent(agent_name="team-reviewer", ...)` with template C
   (worktree path, changed files, design doc, what to check hard — point to the design's sections
   instead of restating their rules: a restated rule becomes the reviewer's answer key; the
   reviewer's shell is read-only and runs no tests); the coordinator checks `git diff --stat` against
   the reported files and the doc's scope and re-runs the definition of done, minus `after <step>`
   commands (the worker's report is a claim, not evidence); activate `ponytail-review` via
   `activate_skill(name="ponytail-review")` and review the diff — judge each item like a finding (it
   never cuts validation, data-loss handling, security); a failed pass is reported, never read as
   "lean already". Accepted items go back to the same worker as "Apply review: …"; in round 2 every
   reviewer that asked for changes re-checks only what changed. Once the code review approves a
   feature, the coordinator runs its post-review steps (the user's: wait for their "done") and `after
   <step>` commands, then the full suites (Rules: Tests); a milestone's slices leave the full suites
   to the end of the run.
7. **Report** (template T).

## Orca worker
- Needs an Orca worktree: `orca worktree current --json` → `"ok": true`. Without Orca, after the gate
  give the user the spec with "ask me here" instead of `ask` and "list the modified files and the
  definition-of-done output" instead of `worker_done`; they come back for step 6.
- Orca's own guide (`orca skills get orchestration`) is the authority on commands; where it and this
  file disagree, the guide wins. Activate the `orchestration` skill via
  `activate_skill(name="orchestration")` when starting orchestration.
- Start (one run per feature or milestone):
  ```bash
  orca orchestration run-create --objective "<feature>" --json
  orca orchestration worker-start --spec "<spec>" --worktree current --agent gemini --timeout-ms 120000 --json
  # another implementer if user requested Claude: --agent claude --model sonnet
  orca orchestration worker-show --dispatch <ctx_id> --json     # → terminal handle
  orca terminal read --terminal <handle> --screen --json        # must show the chosen agent (Gemini CLI by default), or stop
  # no terminal → orca orchestration worker-read --dispatch <ctx_id> --source auto --json
  ```
  `worker-start` exits non-zero → don't relaunch: read `failedStage` and `residualResources`.
  Parallel slices in child worktrees: `foundation.md` Build.
- Next task for the same worker (a fix round, or the next slice): `worker-start --spec "<spec>"
  --terminal <handle> --worktree <its worktree: current | path:<child>> --json` once its dispatch
  settled, then `--ack` the old delivery and wait on the new dispatch. A released worker's slice
  restarts with a new worker in that slice's worktree (`--worktree path:<path>`, same `--agent` and
  `--model`).
- Wait: `orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 540000
  --json`; process every message (a question → `orca orchestration reply --id <msg_id> --body
  "<answer>" --json`), accept `worker_done` only from the dispatch you're waiting on, then `--ack
  <deliveryId>`. Timeouts and empty waits are normal (a build takes 15–60 minutes). After three empty
  waits: `worker-list --run <run_id> --include-remote --json` and `worker-show --dispatch <ctx_id>
  --json` — a non-null `observation.agentWait` is a prompt only a human can answer; answer it with
  `orca terminal send`.
- **Stalled worker** (some agents have no model timeout and wait forever on a dropped response): after
  each empty wait read its screen; two in a row showing the same model step (thinking or responding,
  not a running command) with nothing new but the elapsed timer → `worker-stop --dispatch <ctx_id>`,
  then a new worker in the same worktree (same `--agent`/`--model`) with the spec plus "A stopped
  worker left partial work here (`git status`, `git diff`): keep what fits the design, finish the
  rest." One restart per slice; stalled again → stop and report.
- Finish: `worker-release --dispatch <ctx_id>` for every settled dispatch (before removing its
  worktree); `worker-list --run <run_id> --terminal-state reclaimable` must return none. Never stop or
  release because of a timeout or idle (a stall is neither).

## Templates
**D — design doc**
```
Goal (one paragraph) · Product plan: flows, policies and edge cases as decided, and the assumptions
(none when users don't see the change) · Foundation refs (if any) · Scope: files to create/modify ·
Interfaces, schemas,
signatures · Implementation order · Definition of done: the commands covering this change (Rules:
Tests; `after <step>` for one that needs a post-review step) · Full suites (a milestone lists them
once, at its end) · Do-not-touch · Not doing (and why) · Production steps: what it needs to work in
production (settings, secrets, schedulers, external setup), each with who and where, or none ·
Deferred (findings any review left for later, each with why) — a milestone has these last two once,
at its end
+ for anything new it picks: the options found today and why this one, with sources and dates
```
**R — design review request**
```
Break the design; list only problems, each with evidence (file:line / behaviour / contract). Check:
files and call sites exist; signatures match the code; regressions, migrations, rollback; a row,
field, state or setting whose meaning changes: every function, screen and job that reads or writes it
is in the scope or under Not doing; definition of done runnable and no wider than the change (no full
suites, no repeats without a noted flake);
money/data: double-processing, races, state on failure; anything the implementer would have to guess;
something in the repo, or available today, already does this (cite source and date); hand-rolled what
the platform already provides (auth, queues, cron, rate limits); ponytail ladder on every component
(needed at all? reuse? stdlib? native? one line?); contradicts the foundation; a flow or edge case the
product plan or the design misses, or a rule that fails on a real case (input → result); a production
step missing.
## Critical (evidence required)  ## Missing  ## Ambiguous (questions)  ## Cut (ponytail)
## Verdict: needs revision | ready
```
**C — code review format**
```
## Verdict: APPROVE | REQUEST_CHANGES
## Spec check — quote the design line: missing or partial · not asked for · implemented but wrong ·
the line itself fails in a real case (input → wrong result: the design can be wrong)
## Test check — each test added for new behaviour: would it fail with the change reverted (judge from
the diff)? fed real input (or its real shape), not output of the code under test? A no is a required
change.
## Required changes (file:line)   ## Suggestions
```
**G — approval gate**
```
## Design ready — approval requested
Document · one-line summary · product plan: its assumptions, or none (why) · implementer (agent ·
model; default: gemini; the user may change it here) · scope (N files) · key decisions · review: raised / accepted / rebutted / deferred
(a failed or partial review is stated) · not doing · definition of done · risks · foundation lines not
followed, and why (a founded repo)
Reply "approve" or "go", or tell me what to change.
```
**P — product plan** (in the user's language; what users see and do, no files, APIs or schemas)
```
## Goal — who gets what  ## Flows — each actor's steps, happy path first
## Policies and edge cases — rules, limits, permissions, failure, empty / duplicate / late input, each
with its behaviour  ## Existing options — how products in this domain do it, searched today
(`google_web_search`), sources with dates (or none); a source the design relies on is opened
(`web_fetch`) first  ## Not doing  ## Open questions — business calls
only, each with options and your recommendation
```
**S — worker spec**
```
Read the design doc first: <absolute path>. Implement <all of it | slice …> in its order.
Before coding, read the repo's CLAUDE.md and GEMINI.md files covering the paths you touch (root and
nested) and follow them.
Definition of done: <commands>; run it once at the end, minus `after <step>` commands (a fix round:
only what failed and what covers the files you changed), and put the results in worker_done. While
working, run only the tests your change touches; the coordinator runs the full suites.
Only touch the doc's scope. Ask (the preamble's `ask`) before deviating or cutting anything; no plan
mode; don't commit; list every modified file in worker_done --files-modified. ponytail is on: use it
for how you write the code, but build everything the design specifies. Write your questions and
worker_done in <the user's language>.
```
**T — report**: first, each goal and done criterion of the user's request or milestone: met / partly /
not, with evidence (a file, a command's output) — a partly or not opens the report and the work is not
called done · design doc · files · what review changed · code review rounds and fixes ·
`ponytail-review` applied / rejected · tests and full suites (fresh output from your own run; after a
fix, which ones re-ran) · production steps left to do (the design doc's: who, where) · open issues,
and deferred findings with why.

## Gotchas
- The reviewer is the `team-reviewer` subagent (`invoke_agent(agent_name="team-reviewer", ...)`),
  read-only through `~/.gemini/policies/team-reviewer.toml`. Unavailable in this session → the review
  failed: say so and ask the user to restart Gemini. Never review through `generalist` or another
  agent: no policy holds them, and they can write.
- No `## Verdict:` → invoke `team-reviewer` once more requiring the verdict; still nothing → the
  review failed (say so). A review that lists unchecked areas is partial: check them yourself, never
  call it a full approval.
- Orca pre-grants folder trust where it launches workers; a worker still stuck at a trust prompt shows
  up as `agentWait`.
- An orchestration write (`reply`) failing with `stable_pane_required` (the driver runs in a terminal
  without a fixed pane, e.g. a floating one) → repeat it with `--run <run_id> --from <coordinator_handle
  from run-create>`; until then the worker sits waiting for the answer.
- Orca types "You have N orchestration message…" into the driver as a user turn. It isn't the user:
  answer with a one-line status.
