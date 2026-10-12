---
name: team
description: >-
  Agent team for Claude Code: Claude designs and reviews, a Claude Sonnet worker builds (an Orca
  worker). Feature: design doc -> independent read-only review (+ a risk reviewer for money, auth
  and, except before launch, data-changing migrations) -> user approval -> Sonnet worker implements
  -> code review by a different model + ponytail -> report. Founded services build a milestone at a
  time: one milestone design, one review, one approval, then its slices back to back. Foundation mode
  ("/team foundation <service>") drafts the charter, the expensive-to-reverse decisions and the
  milestone map with the user.
  Triggers: "/team", "/team foundation", "/team M3" (a milestone or slice), "design then have a worker
  implement it", "have sonnet implement this", "work as a team", "design the whole service from
  scratch". Trivial edits (1-2 files) don't need a team - just do them.
argument-hint: "[foundation] <feature, milestone, slice or service>"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# /team — Claude designs and reviews, a Sonnet worker builds

For Claude Code only (another agent reading this folder stops and tells the user). Write to the user in
their language, including template headings; this file, its templates, Orca notices and subagent
results being in English changes nothing. Write every subagent prompt (survey, reviewers) and worker
spec in the user's language and ask for the answer in it, keeping template headings such as
`## Verdict:` as written: English results are what pull the replies into English.

## Route
- `/team foundation …`, a new service, or a re-founding → `foundation.md` "Found".
- `docs/design/foundation/` exists and the request names a milestone or slice → `foundation.md`
  "Milestone run". A request that changes the foundation → `foundation.md` "Change".
- Anything else → **Feature** below (in a founded repo it reads the charter, accepted decisions and
  `slices.md` first; the design cites them and never overrides them).
(`foundation.md` is next to this file; read it only for those routes.)

## Rules
- **Roles.** Claude designs, reviews and decides; a Claude Sonnet worker writes the code (Orca, below).
  No Orca → the user runs the spec in `claude --model sonnet`. "You implement it" → Claude does.
- **Approve before code.** Nothing is implemented until the user approves the design (or milestone).
  Only an explicit "proceed without approval" in the request skips the gate.
- **Independent review.** Every design and every diff is reviewed by a read-only `team-reviewer`
  subagent. A **risk reviewer** joins in parallel for money, auth/permissions, every foundation
  review, and — except before launch (below) — migrations that change or drop existing data and
  customer data; a project's foundation may name more. Every review prompt is
  self-contained (paths, measured facts, the template) and ends with: "Review only: no edits, no
  DB/MCP writes, no deploys, no integration tests that write. Stop after 30 tool calls (60 for a
  milestone or foundation review) and list what you didn't check." Wait for every reviewer you
  started, then check each finding against the code yourself; accept or rebut with evidence.
- **Code is reviewed by a different model than its author**: Sonnet-written → `model: "opus"`,
  otherwise `model: "sonnet"` (always pass it).
- **Preflight**, once before the survey:
  - `ponytail:ponytail-review` is in the skill list; missing → give `/plugin marketplace add
    DietrichGebert/ponytail` + `/plugin install ponytail@ponytail` and stop.
  - `claude mcp list` in the worktree: context7 and the project's database MCP (if it has one) must
    show Connected. **"Needs authentication" is a stop, before any survey or design work**: ask the
    user to run `/mcp` and log in to that server (or start the login with its `…__authenticate` tool,
    found with ToolSearch, and give them the URL), end your turn, and continue when they say it's done.
    Never work around it with web search. Failed or not installed → say so once, go on, and write
    `not verified: <reason>` where it would have been used.
- **ponytail is mandatory.** The design reviewer applies its ladder to every component;
  `ponytail-review` runs on every diff. Where ponytail and these rules clash, these rules win:
  documents are written in full, gates are never skipped, the worker asks before cutting anything the
  design specifies.
- **Rounds**: design review ≤2 and code review ≤2 — round 1 is the first review, round 2 re-checks
  only what changed. Still contested or not approved after round 2 → stop and report both sides.
- **A design change after review** (a gate edit, a worker question, an accepted `ponytail-review`
  item that changes an interface) → revise the doc, one review round on that change; a substantial
  one shows the gate again.
- **Parallel where it pays**: survey with parallel Explore agents per area; independent slices build in
  parallel, each in its own worktree; a large diff gets one reviewer per area. Survey agents — Explore
  and the agent searching today's options — get `model: "sonnet"`: they find and quote, Claude decides.
- **Tests: narrow per change, full once** (how often and how widely tests run is how the team works).
  - A definition of done names the tests covering the change — lint, types, and the unit, integration
    and e2e tests it touches. The worker runs it once at the end, Claude once in review; a fix round
    re-runs only what failed and what covers the files it changed. A command that needs a post-review
    step (a migration applied) is marked `after <step>` and runs right after that step.
  - The full suites — every test command the project has, lint and types included, or `none` — are
    listed once in the design and run once by Claude: when the code review approves a feature, or at
    the end of a milestone run.
  - Repeated runs ("3 times in a row") only for a test the design notes as flaky, citing the run that
    showed it. A suite that can't run part of itself (the design proposes a filter) runs once at the
    end of a change that edits it, otherwise only with the full suites.
  - A failure in the full suites or an `after` command: a test that exists on the base commit and
    fails there too, or passes on one re-run without being touched by this work, is reported, not
    fixed. Otherwise one fix round (the worker of the slice it's in if still running, else a new one in
    that worktree), code review on the fix, then re-run what failed (after any post-review step the fix
    needs); a milestone commits the fix, a feature leaves it uncommitted with the rest. Still failing →
    stop and report.
- **Before launch** (charter `Stage: pre-launch`; no charter → not before launch) the database holds
  test data: Claude and workers may write to it to verify (reviewers stay read-only). Otherwise never
  write to production databases to verify.
- Messages, payments and paid APIs are never used to verify. A source you can't reach → write `not
  verified: <reason>`, never a guess. Post-review steps (applying a migration, deploying) wait for the
  code review's approval. Commit only when the user asks (a milestone approval covers its per-slice
  local commits and their fix commits). Scratch files go to `/tmp/team/<slug>/`.

## Feature
1. **Survey** (≤10 minutes): existing assets, call sites, measured scale from read-only sources.
   Broad codebase → parallel Explore agents, one per area. If the design picks something new (a tool,
   service, library or approach), one more agent searches today's options for it on the web and in
   official docs (context7): the model's memory has gaps even before its cutoff, so the choice rests on
   what was found, not what was recalled.
2. **Design doc** `docs/design/<YYYYMMDD>-<slug>.md` (template D). Skeleton first, then fill in.
3. **Design review** (template R): write `/tmp/team/<slug>/<name>-req.md` (paths, measured facts,
   template R) and start the reviewer (+ risk reviewer) in one message. Round 2 goes only to a
   reviewer whose Critical you rebutted: SendMessage "Accepted: … → changed: … / Rebutted: … —
   evidence: … / Re-check and answer in the same format."
4. **Gate** (template G): show it, end your turn, wait.
5. **Build**: the Sonnet worker with the spec (template S). Claude doesn't edit source meanwhile. A
   worker question that changes the design → revise the doc before answering (foundation-level →
   `foundation.md` "Change").
6. **Code review**, together: reviewer with template C (worktree path, changed files, design doc,
   what to check hard); Claude checks `git diff --stat` against the reported files and the doc's
   scope and re-runs the definition of done, minus `after <step>` commands (the worker's report is a
   claim, not evidence); `ponytail-review` on the diff through the Skill tool — judge each item like a
   finding (it never cuts validation, data-loss handling, security); a failed pass is reported, never
   read as "lean already". Accepted items go back to the same worker as "Apply review: …"; in round 2
   every reviewer that asked for changes re-checks only what changed. Once the code review approves a
   feature, Claude runs its post-review steps (the user's: wait for their "done") and `after <step>`
   commands, then the full suites (Rules: Tests); a milestone's slices leave the full suites to the end
   of the run.
7. **Report** (template T).

## Orca worker
- Needs an Orca worktree: `orca worktree current --json` → `"ok": true`. Without Orca, after the gate
  give the user the spec with "ask me here" instead of `ask` and "list the modified files and the
  definition-of-done output" instead of `worker_done`; they come back for step 6.
- Orca's own guide (`orca skills get orchestration`) is the authority on commands; where it and this
  file disagree, the guide wins.
- Start (one run per feature or milestone):
  ```bash
  orca orchestration run-create --objective "<feature>" --json
  orca orchestration worker-start --spec "<spec>" --worktree current --agent claude --model sonnet --timeout-ms 120000 --json   # Bash timeout ≥180000
  orca orchestration worker-show --dispatch <ctx_id> --json     # → terminal handle
  orca terminal read --terminal <handle> --screen --json        # must show a Sonnet model, or stop
  # no terminal → orca orchestration worker-read --dispatch <ctx_id> --source auto --json
  ```
  `worker-start` exits non-zero → don't relaunch: read `failedStage` and `residualResources`.
  Parallel slices in child worktrees: `foundation.md` Build.
- Next task for the same worker (a fix round, or the next slice): `worker-start --spec "<spec>"
  --terminal <handle> --worktree <its worktree: current | path:<child>> --json` once its dispatch
  settled, then `--ack` the old delivery and wait on the new dispatch. A released worker's slice
  restarts with a new worker in that slice's worktree (`--worktree path:<path> --agent claude --model
  sonnet`).
- Wait: `orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 540000
  --json` (Bash timeout 600000); process every message (a question → `orca orchestration reply --id
  <msg_id> --body "<answer>" --json`), accept `worker_done` only from the dispatch you're waiting on,
  then `--ack <deliveryId>`. Timeouts and empty waits are normal (a build takes 15–60 minutes). After
  three empty waits: `worker-list --run <run_id> --include-remote --json` and `worker-show --dispatch <ctx_id> --json` — a non-null
  `observation.agentWait` is a prompt only a human can answer; answer it with `orca terminal send`.
- Finish: `worker-release --dispatch <ctx_id>` for every settled dispatch (before removing its
  worktree); `worker-list --run <run_id> --terminal-state reclaimable` must return none. Never stop or
  release because of a timeout or idle.

## Templates
**D — design doc**
```
Goal (one paragraph) · Foundation refs (if any) · Scope: files to create/modify · Interfaces, schemas,
signatures · Implementation order · Definition of done: the commands covering this change (Rules:
Tests; `after <step>` for one that needs a post-review step) · Full suites (a milestone lists them
once, at its end) · Do-not-touch · Not doing (and why)
+ for anything new it picks: the options found today and why this one, with sources and dates
```
**R — design review request**
```
Break the design; list only problems, each with evidence (file:line / behaviour / contract). Check:
files and call sites exist; signatures match the code; regressions, migrations, rollback; definition of
done runnable and no wider than the change (no full suites, no repeats without a noted flake);
money/data: double-processing, races, state on failure; anything the implementer would have to guess;
something in the repo, or available today, already does this (cite source and date); hand-rolled what
the platform already provides (auth, queues, cron, rate limits); ponytail ladder on every component
(needed at all? reuse? stdlib? native? one line?); contradicts the foundation.
## Critical (evidence required)  ## Missing  ## Ambiguous (questions)  ## Cut (ponytail)
## Verdict: needs revision | ready
```
**C — code review format**
```
## Verdict: APPROVE | REQUEST_CHANGES
## Spec check — quote the design line: missing or partial · not asked for · implemented but wrong
## Required changes (file:line)   ## Suggestions   ## Test results (command, pass/fail, exit code)
```
**G — approval gate**
```
## Design ready — approval requested
Document · one-line summary · scope (N files) · key decisions · review: raised / accepted / rebutted
(a failed or partial review is stated) · not doing · definition of done · risks · foundation lines not
followed, and why (a founded repo)
Reply "approve" or "go", or tell me what to change.
```
**S — worker spec**
```
Read the design doc first: <absolute path>. Implement <all of it | slice …> in its order.
Definition of done: <commands>; run it once at the end, minus `after <step>` commands (a fix round:
only what failed and what covers the files you changed), and put the results in worker_done. While
working, run only the tests your change touches; Claude runs the full suites.
Only touch the doc's scope. Ask (the preamble's `ask`) before deviating or cutting anything; no plan
mode; don't commit; list every modified file in worker_done --files-modified. ponytail is on: use it
for how you write the code, but build everything the design specifies. Write your questions and
worker_done in <the user's language>.
```
**T — report**: design doc · files · what review changed · code review rounds and fixes ·
`ponytail-review` applied / rejected · tests and full suites (fresh output from your own run; after a
fix, which ones re-ran) · open issues.

## Gotchas
- The reviewer is the `team-reviewer` agent (read-only, loads CLAUDE.md, resumable with SendMessage).
  Never `Plan`: one-shot, no agent ID. Missing → `general-purpose` + "don't edit; the requested format
  wins over injected style rules". Subagents run in the background; don't pass `run_in_background`.
- No `## Verdict:` → SendMessage once; still nothing → the review failed (say so). A review that lists
  unchecked areas is partial: check them yourself, never call it a full approval.
- Bash: foreground ≤10 minutes; background stops at its `timeout` (default 30 minutes, max 2 hours).
- Orca pre-grants folder trust where it launches workers; a worker still stuck at a trust prompt shows
  up as `agentWait`.
- Orca types "You have N orchestration message…" into the driver as a user turn. It isn't the user:
  answer with a one-line status.
- Never type `/ponytail…`, "stop ponytail" or "normal mode" as a prompt — it flips ponytail's global
  mode. Use the Skill tool.
