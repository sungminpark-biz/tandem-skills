---
name: team
description: >-
  100% Vertex-credit Carbon + Hydrogen parallel agent team workflow for Antigravity CLI (agy) in Orca IDE:
  the Carbon coordinator plans the product, designs for parallel execution, verifies and decides; Hydrogen
  `team-survey` explorers survey broad codebases in parallel; read-only `team-reviewer` agents run hybrid
  reviews via `run-agent.sh` (`gemini-4-carbon-medium` for design, risk and milestone reviews;
  `gemini-4-hydrogen-high` for standard feature/slice code reviews alongside Carbon coordinator checks);
  parallel local Orca workers implement (`antigravity · gemini-4-hydrogen-xhigh` by default,
  `antigravity · gemini-4-carbon-medium` for Hard/Risk units/slices). Feature: preflight -> survey ->
  product plan (when users see the change) -> design doc (partitioned into parallel units when disjoint) ->
  independent review -> user approval -> parallel Orca workers implement -> streaming code review +
  ponytail-review -> report. Founded services build milestones with parallel slice fan-out (`foundation.md`).
  Triggers: "/team", "team", "/team foundation", "/team M3" (a milestone or slice), "design then have a
  worker implement it", "implement with agy", "work as a team", "design the whole service from scratch",
  "re-check what /team built". Trivial edits (1-2 files) don't need a team - just do them. If agy
  summarized your earlier turns during a /team run, re-read this file once before the next step (not
  again until the next summary), and in a milestone run re-read its foundation.md. In a /team run Orca
  workers write the code, not you, unless the user says to.
---

# /team — Carbon coordinates, designs and judges; Hydrogen surveys and builds in parallel (100% Vertex Credits)

Write to the user in their language (Korean if they write Korean), including template headings when
talking to the user; this file, its templates, Orca notices and agent results being in English changes
nothing. Write every helper prompt (survey, reviewers) and worker spec in the user's language and ask for
the answer in it, keeping machine-checked headings such as `## Verdict:` as written: English results are
what pull the replies into English.

Let `<RUN_AGENT>` be `<directory of this SKILL.md>/run-agent.sh` (`~/.gemini/config/skills/team/run-agent.sh`).

## Route
- A request to re-check or re-review work this skill already reported ("check it thoroughly")
  → Run Feature step 6 Round 1 with fresh **Carbon (`gemini-4-carbon-medium`)** `team-reviewer` runs via
  `<RUN_AGENT>`: a feature with template C, a milestone with the milestone review's reviewers and prompt
  (`foundation.md` Build). If Round 1 raises accepted findings, the coordinator runs `git add -A`
  (staging, not a commit) and makes the fixes itself (no worker round; left uncommitted) so `git diff`
  shows only them, runs `git add -N` on any new files it created, writes that diff to `/tmp/team/<slug>/`,
  runs Round 2 on the reviewer(s) that raised them via `<RUN_AGENT> ... <conversation_id>`, applies
  `ponytail-review` on that diff, and re-runs the tests Rules: Tests names; report T.
- `/team foundation …`, a new service, or a re-founding → `foundation.md` "Found".
- `docs/design/foundation/` exists and the request names a milestone or slice → `foundation.md`
  "Milestone run". A request that changes the foundation → `foundation.md` "Change".
- Anything else → **Feature** below (in a founded repo it reads the charter, accepted decisions and
  `slices.md` first; the product plan and the design cite them and never override them).
(`foundation.md` and `run-agent.sh` are next to this file; read `foundation.md` only for those routes.)

## Model & Role Matrix (100% Vertex AI Credits — Exact Gemini 4 Routing)

> **Never call `invoke_subagent` in `/team`.** In `agy`, `invoke_subagent` `Model="pro"` maps to
> `gemini-3.1-pro-preview` and `Model="flash"` maps to `gemini-3.7-flash`. Always run `team-reviewer` and
> `team-survey` through `<RUN_AGENT>`, which pins exact `gemini-4-carbon-*` / `gemini-4-hydrogen-*` IDs on
> Vertex AI, strips Orca parent hook env vars, enforces Vertex-only billing, and supports Round 2
> `--conversation <id>` with Vertex context cache hits.

| Role | Executor | Exact Vertex Model | When used |
| :--- | :--- | :--- | :--- |
| **Coordinator** | Main `agy` session | **Gemini 4 Carbon** (`medium` / `high`) | Product plan, parallel-first design doc, verifying every finding against code, `ponytail-review`, running DoD & full suites, gates, reports |
| **Codebase Survey** | `<RUN_AGENT>` (`team-survey`) | **`gemini-4-hydrogen-high`** | Parallel per-area local codebase exploration on broad tasks (≥2 areas; `read_file` only). *Coordinator runs `search_web` itself.* |
| **Deep / Risk Review** | `<RUN_AGENT>` (`team-reviewer`) | **`gemini-4-carbon-medium`** | Every design review, risk reviewer (design & code), foundation review, milestone whole-diff review, launch review, re-check route |
| **Standard Code Review** | `<RUN_AGENT>` (`team-reviewer`) | **`gemini-4-hydrogen-high`** | Step 6 code review (template C) per unit/slice on non-risk work, paired in the same turn with Carbon coordinator diff + `ponytail-review` + DoD test checks |
| **Default Orca Worker** | `orca orchestration worker-start` | `antigravity` · **`gemini-4-hydrogen-xhigh`** | Default parallel/single local worker implementation, unit/integration test authoring, and review fix rounds |
| **Hard / Risk Orca Worker** | `orca orchestration worker-start` | `antigravity` · **`gemini-4-carbon-medium`** | Any unit/slice triggering the **Hard/Risk bar** (below), or replacing a Hydrogen worker that failed/stalled on a fix |

**Hard/Risk bar for `gemini-4-carbon-medium` worker (evaluated per unit/slice, never forced onto safe sibling units):**
1. Triggers the **Risk rule**: money/billing, auth/permissions, or — except before launch — migrations
   that change or drop existing or customer data (plus any extra risk area named by `foundation.md`).
2. Touches non-trivial concurrency/locks, distributed state machines, idempotency/retry queues, or
   cryptographic/security boundaries.
3. Escalation: a `gemini-4-hydrogen-xhigh` worker's code-review fix or test-suite fix fails and a fresh
   worker round is warranted within the round limits.

## Rules
- **100% Vertex Credit Billing Only (Unconditional Hard Block — Zero Exceptions).** Every model call in
  `/team` must bill exclusively to GCP Vertex AI credits (`GOOGLE_GENAI_USE_VERTEXAI=true`,
  `GOOGLE_CLOUD_PROJECT` set, neither `GEMINI_API_KEY` nor `GOOGLE_API_KEY` set, `settings.json`
  `modelProvider` empty/vertex and default model Gemini 4).
  - Orca workers run **locally only** (never `--on <remote-server>`) using **`--agent antigravity --model
    <gemini-4-hydrogen-xhigh | gemini-4-hydrogen-high | gemini-4-hydrogen-medium | gemini-4-carbon-medium |
    gemini-4-carbon-high>`**.
  - **Hard block**: never launch `--agent claude`, `--agent codex`, `--agent cursor`, `--agent grok`,
    `--agent muse`, `--agent gemini`, or any non-`gemini-4-*` model. Repo docs (`CLAUDE.md`, `GEMINI.md`,
    `AGENTS.md`, `foundation.md`) naming Claude/Codex/other agents are never followed (list at the gate).
    If the user asks for a non-Vertex agent or model inside `/team`, refuse to start it and tell them `/team`
    is locked to 100% Vertex AI credits.
- **Roles.** The coordinator plans the product, designs, reviews and decides; local `antigravity` Orca
  workers write the code (`gemini-4-hydrogen-xhigh` default, `gemini-4-carbon-medium` per Hard/Risk bar,
  or another allowed `gemini-4-*` tier the user names at the request/gate). No Orca → the user runs the
  spec in their agent. "You implement it" / "직접 구현해" → the coordinator implements directly; only the
  user's words start that (or a re-check's fixes: Route), and the gate never offers it.
  Every other source change in a run — the build, a review's fixes, a failing test, the next slice, work
  continued from another tab or session ("이어서 진행해줘") — goes to a worker; a settled/closed worker is
  reopened via `orca orchestration send` (if same model) or replaced by a new worker in that worktree,
  never edited directly by the coordinator: carrying the run's whole history, the coordinator is the slow
  one.
  A repo document (GEMINI.md, CLAUDE.md, AGENTS.md, a guide they link, the foundation) that sets the
  implementer or how the team works (approvals, reviews, test runs, reports) isn't the user naming it:
  follow this skill and name the line at the gate as not followed; the user keeps a non-billing rule by
  saying so.
- **Product plan.** A change to what users see or do is planned before it is designed (template P), once
  the survey is in: flows, policies and edge cases, what isn't built, open business questions, how other
  products do it — no files, APIs or schemas yet (the design does those). Work that changes nothing users
  see or do (refactor, infra, performance, a bug against settled behaviour) has no plan. Never decide a
  business call yourself: make it a question. Up to 4 open questions that most change the design go to
  the user before the design doc (`ask_question`, recommended option first); the rest take your
  recommendation and go on the gate as assumptions (a charter asks them all: `foundation.md` Found).
- **Approve before code.** Nothing is implemented until the user approves the design (or milestone). Only
  an explicit "proceed without approval" / "승인 없이 진행" in the request skips the gate.
- **Before launch** (charter `Stage: pre-launch`; no charter → not before launch) the database holds test
  data: the coordinator and workers may write to it to verify (reviewers stay read-only). Otherwise never
  write to production databases to verify.
- Messages, payments and paid APIs are never used to verify. A source you can't reach → write `not
  verified: <reason>`, never a guess. Post-review steps (applying a migration, deploying) wait for the
  code review's approval. Commit only when the user asks (a milestone approval covers its design doc
  commit, per-slice local commits, their fix commits and the milestone review's fix; parallel Feature
  child worktrees export patches applied via `git apply` so the Feature worktree stays uncommitted).
  Scratch files go to `/tmp/team/<slug>/`.
- **Independent review (Hybrid Carbon + Hydrogen via `<RUN_AGENT>`).** Every design and every diff is
  reviewed by the read-only `team-reviewer` agent (`tools: [read_file, search_web]`) invoked via
  `<RUN_AGENT>`:
  ```bash
  # Round 1:
  ~/.gemini/config/skills/team/run-agent.sh <model> team-reviewer \
    /tmp/team/<slug>/<name>-req.md /tmp/team/<slug>/<name>-r1.json
  # Round 2 (reuses conversation + Vertex context cache):
  ~/.gemini/config/skills/team/run-agent.sh <model> team-reviewer \
    /tmp/team/<slug>/<name>-r2-req.md /tmp/team/<slug>/<name>-r2.json <conversation_id>
  ```
  - **Design reviews, foundation reviews, milestone whole-diff reviews, launch reviews, and re-checks**
    use **`gemini-4-carbon-medium`**.
  - **Feature unit and slice code reviews (template C)** use **`gemini-4-hydrogen-high`**.
  - A **risk reviewer** — a second parallel `<RUN_AGENT>` call on **`gemini-4-carbon-medium`** — joins in
    the same turn (`WaitMsBeforeAsync: 500` when running ≥2 commands in parallel) on both design review and
    code review for money, auth/permissions, every foundation review, and — except before launch —
    migrations that change or drop existing data and customer data; a project's foundation may name more.
  - Because `team-reviewer` has no tool that writes files or runs commands: before every review, write
    absolute-path file lists (`git ls-files --cached --others --exclude-standard | sed "s|^|$PWD/|"`),
    `grep -rn` of the names the design or diff changes, and — for a code review — status and full diff
    (including newly created files via `git add -N`, see Step 6) into `/tmp/team/<slug>/` (rewrite updated
    diff/status/refs files before Round 2 too), and pass those paths in `<name>-req.md` (keep
    `<name>-req.md` under 200KB by referencing paths, never pasting diffs inline).
  - Every review prompt file is self-contained (paths, measured facts, the template) and ends with:
    "Review only: no edits, no DB/MCP writes, no deploys, no tests (the coordinator runs them). Stop
    after 30 tool calls (60 for a milestone design review, the milestone review or a foundation review)
    and list what you didn't check."
  - Wait for every reviewer you started, then check each finding against the code yourself (Carbon
    coordinator judgment); accept, rebut with evidence, or defer (Deferring a finding).
  - **When Round 2 runs**: run Round 2 (`<name>-r2-req.md` + `<conversation_id>` from `<name>-r1.json`) for
    every reviewer whose Round 1 verdict was `needs revision` / `REQUEST_CHANGES`, or whose Critical /
    required item you rebutted or deferred:
    `Accepted: … → changed: … / Rebutted: … — evidence: … / Deferred: … — why: … / Updated files: <paths>. Re-check only what changed and answer in the same format.`
    If resuming `<conversation_id>` fails, run a fresh `<RUN_AGENT>` at the same model with the Round 1
    summary included.
- **ponytail is mandatory.** The design reviewer applies its ladder to every component; `ponytail-review`
  runs on every diff. Where ponytail and these rules clash, these rules win: documents are written in full,
  gates are never skipped, the worker asks before cutting anything the design specifies.
- **Rounds**: design review ≤2 and code review ≤2 — round 1 is the first review, round 2 re-checks only
  what changed. Still contested or not approved after round 2 → stop and report both sides.
- **A design change after review** → revise the doc. A gate edit, a worker question or an accepted
  `ponytail-review` item that changes an interface: one review round on that change. A review finding
  that the design itself is wrong: the fix follows the revised line and the reviewer that raised it
  checks both in its round 2. A substantial change shows the gate again.
- **Deferring a finding** depends on the harm it can cause, never on slice or file boundaries ("this
  slice doesn't touch the database"). One that can lose real data (not test data) or money, do something
  that can't be undone, cut someone off, or show a real person something false is fixed in this run — its
  own fix round, or in a milestone the milestone review's fix (`foundation.md` Build) — and a business
  call in it goes to the user. Every deferral goes under `Deferred` in the design doc with its reason;
  one held for the milestone review's fix is marked `→ milestone fix`. A deferred Critical or required
  change is named in round 2 like a rebuttal; a review whose only open items are deferred counts as
  approved once its round 2 doesn't contest a deferral.
- **Parallel-first for speed (Surveys, Workers, Reviews):**
  - **Surveys**: narrow (1 area, few files) → read directly yourself. Broad (≥2 distinct areas/packages) →
    write `/tmp/team/<slug>/ls-files.txt` (`git ls-files --cached --others --exclude-standard | sed
    "s|^|$PWD/|"`) + per-area prompt files and launch parallel background `<RUN_AGENT>
    gemini-4-hydrogen-high team-survey` calls (`WaitMsBeforeAsync: 500`) in **one turn**. `team-survey`
    quotes `file:line`; the coordinator runs `search_web` itself and decides.
  - **Feature & Milestone parallel workers**:
    - **Partition whenever independent**: in Step 2 (Design Doc), split work into **Parallel Units
      (`U1..Uk`, up to 4 concurrent child worktrees for a Feature; up to 5 concurrent slices for a
      Milestone)** whenever ≥2 non-trivial units own **strictly disjoint files** (zero shared modified or
      newly created paths, and none touches `docs/design/`) and each unit compiles/passes its narrow DoD
      against `HEAD`. Keep a single worker in `--worktree current` only when the change is 1–3 files or
      tightly coupled in the same files (where child worktree `--setup run` would cost more time than
      parallel coding saves).
    - **Streaming review & integration**: never block a finished unit/slice's code review on a slower
      sibling worker — review, run narrow DoD, and integrate each unit/slice as soon as its `worker_done`
      arrives.
  - **Large diffs** (>30 files) get one `team-reviewer` per area in parallel (`WaitMsBeforeAsync: 500`).
- **Tests: narrow per change, full once** (how often and how widely tests run is how the team works).
  - A definition of done names the tests covering the change — lint, types, and the unit, integration and
    e2e tests it touches (leave full production builds such as `next build` to the full suites unless the
    change touches build/bundler config). Each unit/slice worker runs its narrow DoD once at the end, the
    coordinator once in that unit/slice's review; a fix round re-runs only what failed and what covers the
    files it changed. A command that needs a post-review step (a migration applied) is marked
    `after <step>` and runs right after that step.
  - The full suites — every test command the project has, lint, types and build included, or `none` — are
    listed once in the design and run once by the coordinator: when all units of a feature are integrated
    and approved, or at the end of a milestone run (skipping any command the coordinator already ran and
    passed on the exact same tree with no fix or post-review step in between).
  - Repeated runs ("3 times in a row") only for a test the design notes as flaky, citing the run that
    showed it. A suite that can't run part of itself (the design proposes a filter) runs once at the end
    of a change that edits it, otherwise only with the full suites.
  - A failure in the full suites or an `after` command: a test that exists on the base commit and fails
    there too, or passes on one re-run without being touched by this work, is reported, not fixed.
    Otherwise one fix round:
    - Single-unit feature (worker still in `current`) or milestone slice: reopen via `orca orchestration
      send` if same model (or release and launch a `gemini-4-carbon-medium` worker if a Hydrogen worker
      struggled).
    - Multi-unit parallel feature (already integrated into `current`, child worktrees removed): in
      `current`, run `git add -A` (staging integrated work without committing, so unstaged `git diff`
      isolates the fix), launch one worker in `--worktree current` (`gemini-4-hydrogen-xhigh`, or
      `gemini-4-carbon-medium` if Hard/Risk), run Step 6 code review + `ponytail-review` on that fix diff,
      re-run what failed, then `git reset -q HEAD` so the feature remains uncommitted/unstaged.
    Still failing → stop and report.
- **Preflight**, once before the survey:
  - Run `~/.gemini/config/skills/team/run-agent.sh --preflight` (verifies 100% Vertex AI credit env/config,
    `ponytail-review`, `team-reviewer`, and `team-survey`). Any non-zero exit is an immediate stop. If
    `default_ui_model` in its output is Hydrogen, note it in one line (`run-agent.sh` and Orca workers
    still pin exact Carbon/Hydrogen via `--model`).
  - Check if the project uses an MCP server (e.g. Supabase/Postgres: `agy mcp list`, or the project's own
    MCP config). If a required project database MCP is disconnected or needs authentication, ask the user
    to authenticate it in `/mcp`, end your turn, and continue when they say it's done. Never work around
    a disconnected project DB MCP with guesses; if not installed or unreachable, state so once and write
    `not verified: <reason>` where it would have been used.
  - `git fetch` (failed → say so; no remote → the local default branch), then compare HEAD with the
    branch this work will merge into (`<base>`, usually `origin/<default branch>`). Behind it with
    nothing of its own (no commits `<base>` lacks, no uncommitted changes to tracked files) →
    `git switch -c <branch> --no-track <base>`; anything else stays, such as a milestone branch with
    unmerged slices. Say in one line which branch the survey reads and how far behind `<base>` it is (a
    squash-merged branch looks like its own commits: the user may say to switch).

## Feature
1. **Survey** (≤10 minutes): existing assets, call sites, measured scale from read-only sources (parallel
   `<RUN_AGENT> gemini-4-hydrogen-high team-survey` runs when broad; direct reads when narrow). If the
   design picks something new (a tool, service, library or approach), the coordinator searches today's
   options on the web (`search_web`): the model's memory has gaps even before its cutoff, so the choice
   rests on what was found, not what was recalled. Then, when users see the change, draft the product plan
   (Rules: template P) from what the survey found, and ask its open questions (`ask_question`).
2. **Design doc** `docs/design/<YYYYMMDD>-<slug>.md` (template D). Skeleton first, then fill in.
   - **Check parallel split**: if ≥2 non-trivial areas own **disjoint files** (modified and newly created
     paths alike, none touching `docs/design/`) and compile/test independently against `HEAD`, partition
     Scope into **Parallel Units `U1..Uk`** (≤4 concurrent child worktrees), assigning each unit its exact
     files, narrow DoD, and worker tier (`gemini-4-hydrogen-xhigh` default, `gemini-4-carbon-medium` if
     that unit hits the Hard/Risk bar). Otherwise keep **1 unit** in `current`.
3. **Design review** (template R): write `/tmp/team/<slug>/ls-files.txt` (`git ls-files --cached --others
   --exclude-standard | sed "s|^|$PWD/|"`), `grep -rn` of the names the design changes, and
   `/tmp/team/<slug>/design-req.md` (paths, measured facts, template R), then run `<RUN_AGENT>
   gemini-4-carbon-medium team-reviewer` (+ parallel risk reviewer on `gemini-4-carbon-medium` with
   `WaitMsBeforeAsync: 500` if applicable) in one turn. For parallel units, the design review also verifies
   zero file overlap and independent compilability against `HEAD`. Run Round 2 via `<conversation_id>` if
   Round 1 returned `needs revision` or if any Critical was rebutted or deferred.
4. **Gate** (template G): show it (naming each unit's exact `antigravity · <model>` and parallel layout),
   end your turn, wait.
5. **Build**:
   - **Single-unit feature**: write `/tmp/team/<slug>/spec.md` (template S), start one Orca worker in
     `--worktree current`, and **end your turn** until Orca wakes you.
   - **Parallel multi-unit feature (`U1..Uk`, ≤4 at once)**: keep `current` clean except for the untracked
     design doc `docs/design/<YYYYMMDD>-<slug>.md` (pass its absolute path in each
     `/tmp/team/<slug>/spec-<unit>.md` so child workers read it directly). Launch all ready units in **one
     turn**:
     ```bash
     orca orchestration worker-start \
       --spec-file /tmp/team/<slug>/spec-<unit-id>.md \
       --task-title "<unit-id>: <title>" \
       --worktree new-child --name <slug>-<unit-id> \
       --base-branch <current-branch> --setup run \
       --agent antigravity \
       --model <gemini-4-hydrogen-xhigh | gemini-4-carbon-medium> \
       --timeout-ms 120000 --json
     ```
     Then **end your turn immediately**. The coordinator doesn't edit source meanwhile. A worker `question`
     that changes the design → revise the doc before replying (foundation-level → `foundation.md` "Change").
6. **Code review & streaming integration**: as each worker settles (`worker_done`), immediately review that
   unit in its worktree (`current` for single-unit; `<child>` path for parallel units) without waiting for
   slower sibling workers:
   - **Capture all modified AND newly created files**:
     1. Run `git -C <worktree> status --porcelain -uall > /tmp/team/<slug>/<unit>-status.txt` and verify
        every modified and untracked (`??`) file belongs strictly to that unit's Scope (for single-unit in
        `current`, ignore `docs/design/<YYYYMMDD>-<slug>.md`). Any out-of-scope file → send back to the
        worker to revert/remove before approving.
     2. Run `git -C <worktree> add -N -- <assigned-unit-files>` (intent-to-add: stages nothing and commits
        nothing, so `git diff` includes newly created source and test files!), then write
        `git -C <worktree> diff <base> > /tmp/team/<slug>/<unit>-diff.patch` (or unstaged `git diff` for a
        staged full-suite fix round), `git -C <worktree> ls-files --cached --others --exclude-standard |
        sed "s|^|<worktree>/|" > /tmp/team/<slug>/<unit>-ls-files.txt`, and `grep -rn` of the names the
        design or diff changes to `/tmp/team/<slug>/<unit>-refs.txt` (before Round 2, re-run `git add -N`
        on any new files and overwrite status/diff/ls-files/refs files).
   - Together in a **single parallel turn**:
     - `<RUN_AGENT> gemini-4-hydrogen-high team-reviewer` with template C (`WaitMsBeforeAsync: 500`, point
       to the design's sections rather than restating rules);
     - if that unit triggers the Risk rule, also start the parallel **risk reviewer** via `<RUN_AGENT>
       gemini-4-carbon-medium team-reviewer` (`WaitMsBeforeAsync: 500`);
     - inspect `<unit>-diff.patch`, apply `ponytail-review`, and re-run that unit's narrow DoD (minus
       `after <step>` commands).
   - Judge each finding and `ponytail-review` item against the code yourself (never cut validation,
     data-loss handling, or security; a failed pass is reported, never read as "lean already"). Accepted
     fixes go back to that unit's worker via `orca orchestration send` as "Apply review: …" (or if a
     `gemini-4-hydrogen-xhigh` worker failed Round 1's fix, release it and launch a `gemini-4-carbon-medium`
     worker in that worktree); Round 2 re-runs `<RUN_AGENT>` with `<conversation_id>` on the updated diff.
   - **Atomic uncommitted integration of an approved parallel unit into `current`:**
     1. Inside `<child>`, commit **only** that unit's assigned files (`git -C <child> add -- <unit-files> &&
        git -C <child> commit -m "tmp(<unit-id>)"`) and export a binary-safe patch against `<child>`'s base
        commit: `git -C <child> diff --binary HEAD~1..HEAD > /tmp/team/<slug>/<unit-id>-apply.patch`.
     2. In `current`, verify atomically before touching any file:
        `git apply --check /tmp/team/<slug>/<unit-id>-apply.patch && git apply /tmp/team/<slug>/<unit-id>-apply.patch`
        (if `git apply --check` fails, **nothing** in `current` or `<child>` was touched — stop and report
        the overlap with `<child>` preserved!).
     3. Only after `git apply` exits `0`: release `<child>`'s worker (`orca orchestration worker-release
        --dispatch <id> --json`) and remove `<child>` (`orca worktree rm --worktree path:<child>`).
   - **Once all units are approved (and applied into `current`)**: in `current`, verify combined
     `git status --porcelain -uall`, run post-review steps (the user's: wait for their "done") and
     `after <step>` commands, then run the **full suites once** (Rules: Tests).
7. **Report** (template T).

## Orca worker
- Resolve the Orca executable once per `orchestration` skill (`$ORCA_CLI_COMMAND` if set → `orca-dev` if
  `$ORCA_DEV_REPO_ROOT` → `orca-ide` on Linux outside Orca → `orca`; shown as `orca` below) and run
  `orca skills get orchestration` once before starting orchestration. Orca's live guide is the authority
  on command syntax; where it and this file disagree on CLI mechanics, the live guide wins (except `/team`'s
  100%-Vertex local `antigravity` constraint always holds).
- Needs a local Orca worktree: `orca worktree current --json` → `"ok": true`. Without Orca, after the gate
  give the user the spec with "ask me here" instead of `ask` and "list the modified files and the
  definition-of-done output" instead of `worker_done`; they come back for step 6.
- **Start** (one Run per feature or milestone; write spec to `/tmp/team/<slug>/spec-<id>.md` first so
  Korean text, quotes and backticks need no shell escaping):
  ```bash
  orca orchestration run-create --objective "<feature or milestone>" --json
  orca orchestration worker-start \
    --spec-file /tmp/team/<slug>/spec-<id>.md \
    --task-title "<concise title>" \
    --worktree <current | new-child> \
    --agent antigravity \
    --model <gemini-4-hydrogen-xhigh | gemini-4-carbon-medium> \
    --timeout-ms 120000 --json
  # Allowed Vertex-only user overrides: --model gemini-4-hydrogen-high, --model gemini-4-carbon-high
  ```
  - Check the start receipt (`failedStage` / `residualResources` on non-zero exit → do **not** blind
    relaunch; load `orca skills get orchestration --reference references/recovery-and-cleanup.md`).
  - Not every Orca worker uses a PTY terminal: inspect worker output when needed with
    `orca orchestration worker-read --dispatch <dispatch_id> --source auto --json` (never require
    `orca terminal read --screen`).
- **Wait (Reactive Wakeup — Never Poll):**
  - After starting every ready parallel worker for the current step, **end your turn immediately** (call no
    more tools). Never run `check --wait` polling loops or watch scripts — a plain `check` consumes mail
    and prevents Orca from waking you.
  - When Orca wakes you:
    - If a wake notice explicitly names a `check` command (terminal driver or oversized message), run
      that exact command.
    - `question` → answer with `orca orchestration reply --id <message_id> --body "<answer>" --json`
      (if `stable_pane_required`, repeat with `--run <run_id> --from <coordinator_handle from
      run-create>`), revising the design doc first if the answer alters the design; then end your turn if
      waiting on running workers.
    - `escalation` with `approval` → human-only permission prompt; carry on with other ready reviews/work
      or end your turn until its closing message arrives.
    - `escalation` with `stopReason` → worker stopped without `worker_done`: steer it with `send`, or if
      `exited`/`lost`, start one replacement worker in that worktree (same `--agent`/`--model`, or
      escalate `gemini-4-hydrogen-xhigh` → `gemini-4-carbon-medium` if it hit reasoning friction) with
      the spec plus: "A previous worker left partial work here (`git status`, `git diff`): keep what fits
      the design, finish the rest." Max one restart per unit/slice; failed again → stop and report.
    - `worker_done` → settles that Task (never treat a reported failure outcome as completed); start its
      Step 6 review immediately even if sibling parallel workers are still running.
- **Follow-up work (Fix rounds & Sequential dependent slices):**
  - **Same model tier** (a review fix round, a test fix round, or the next dependent slice using the same
    `--agent` and `--model`): write `/tmp/team/<slug>/followup-<id>.md` if long and run:
    ```bash
    orca orchestration send --to dispatch:<dispatch_id> \
      --subject "<Apply review | Slice S...>" \
      --body "<instructions or path to followup file>" --json
    ```
    `send` delivers to an active worker after its turn or automatically reopens a finished/closed local
    worker as a follow-up Task preserving its conversation context, and reports back with `worker_done`.
  - **Model tier change** (switching between `gemini-4-hydrogen-xhigh` and `gemini-4-carbon-medium` across
    dependent slices in the milestone worktree, or escalating a struggling Hydrogen worker to
    `gemini-4-carbon-medium`): once the prior dispatch has settled, release it first
    (`orca orchestration worker-release --dispatch <old_dispatch_id> --json`), then run a fresh
    `worker-start` in that worktree with the new `--model`.
- **Finish & Safety:**
  - Silence, a timeout, or `unverifiable` liveness alone never proves exit or authorizes stopping a
    worker.
  - Follow any `next` action shown by `orca orchestration worker-list --run <run_id> --json`. Release
    every settled dispatch (`orca orchestration worker-release --dispatch <dispatch_id> --json`) before
    removing its child worktree; `worker-list --run <run_id> --terminal-state reclaimable --json` must
    return none at cleanup.

## Templates
**D — design doc**
```
Goal (one paragraph) · Product plan: flows, policies and edge cases as decided, and the assumptions
(none when users don't see the change) · Foundation refs (if any) · Execution & Worker tiers: single unit
in `current` or parallel units `U1..Uk` in child worktrees (why), with each unit's exact `antigravity ·
gemini-4-hydrogen-xhigh` (default) or `antigravity · gemini-4-carbon-medium` (Hard/Risk reason) · Scope:
files to create/modify (per unit when parallel — zero overlap) · Interfaces, schemas, signatures ·
Implementation order · Definition of done: narrow commands per unit + feature change (Rules: Tests;
`after <step>` for one that needs a post-review step) · Full suites (a milestone lists them once, at its
end) · Do-not-touch · Not doing (and why) · Production steps: what it needs to work in production
(settings, secrets, schedulers, external setup), each with who and where, or none · Deferred (findings any
review left for later, each with why) — a milestone has these last two once, at its end
+ for anything new it picks: the options found today and why this one, with sources and dates
```
**R — design review request** (`<RUN_AGENT> gemini-4-carbon-medium team-reviewer`)
```
Break the design; list only problems, each with evidence (file:line / behaviour / contract). Check:
files and call sites exist; signatures match the code; regressions, migrations, rollback; a row,
field, state or setting whose meaning changes: every function, screen and job that reads or writes it
is in the scope or under Not doing; definition of done runnable and no wider than the change (no full
suites, no repeats without a noted flake); worker tier per unit/slice matches the Hard/Risk bar; if split
into parallel units/slices: zero overlapping modified/created files (none touching docs/design/) and each
unit compiles/tests independently against its base; money/data: double-processing, races, state on
failure; anything the implementer would have to guess; something in the repo, or available today, already
does this (cite source and date); hand-rolled what the platform already provides (auth, queues, cron, rate
limits); ponytail ladder on every component (needed at all? reuse? stdlib? native? one line?); contradicts
the foundation; a flow or edge case the product plan or the design misses, or a rule that fails on a real
case (input → result); a production step missing.
## Critical (evidence required)  ## Missing  ## Ambiguous (questions)  ## Cut (ponytail)
## Verdict: needs revision | ready
```
**C — code review format** (`<RUN_AGENT> gemini-4-hydrogen-high team-reviewer` + `gemini-4-carbon-medium` risk reviewer when risky)
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
Document · one-line summary · product plan: its assumptions, or none (why) · execution & implementers
(single unit vs parallel units `U1..Uk`; per unit exact `antigravity · gemini-4-hydrogen-xhigh` or
`antigravity · gemini-4-carbon-medium` with Hard/Risk reason — 100% Vertex credits; you may change any
allowed `gemini-4-*` tier here) · scope (N files, per-unit split) · key decisions · review: raised /
accepted / rebutted / deferred (a failed or partial review is stated) · not doing · definition of done ·
risks · repo lines not followed (foundation, GEMINI.md, CLAUDE.md, guides), and why
Reply "approve" or "go", or tell me what to change.
```
**P — product plan** (in the user's language; what users see and do, no files, APIs or schemas)
```
## Goal — who gets what  ## Flows — each actor's steps, happy path first
## Policies and edge cases — rules, limits, permissions, failure, empty / duplicate / late input, each
with its behaviour  ## Existing options — how products in this domain do it, searched today
(`search_web`), sources with dates (or none); a source the design relies on is searched/verified first
## Not doing  ## Open questions — business calls only, each with options and your recommendation
```
**S — worker spec** (written to `/tmp/team/<slug>/spec-<id>.md`)
```
Read the design doc first: <absolute path>. Implement <all of it | unit U… | slice S…> in its order.
Before coding, read the repo's CLAUDE.md, GEMINI.md and AGENTS.md files covering the paths you touch
(root and nested) and follow them.
Architecture and interfaces are already settled in the design doc: spend your reasoning depth on
edge-case correctness, existing caller compatibility, and test fidelity — never on redesigning settled
interfaces. Ask (the preamble's `ask`) before deviating or cutting anything; no plan mode; don't commit.
Definition of done: <commands>; run it once at the end, minus `after <step>` commands (a fix round: only
what failed and what covers the files you changed), and put the results in worker_done. While working,
run only the tests your change touches; the coordinator runs the full suites.
Only touch <the doc's scope | your assigned unit/slice files — never edit docs/design/ or files owned by
sibling parallel units>. List every modified and newly created file in worker_done --files-modified.
ponytail is on: use it for how you write the code, but build everything the design specifies. Write your
questions and worker_done in <the user's language>.
```
**T — report**: first, each goal and done criterion of the user's request or milestone: met / partly /
not, with evidence (a file, a command's output) — a partly or not opens the report and the work is not
called done · design doc · Vertex billing check (`project` & `tier`) · workers (`antigravity · model`,
parallel units/slices and dispatch ids, plus any escalation, or none: why) · reviewers used
(`gemini-4-carbon-medium` / `gemini-4-hydrogen-high`) · files · what review changed · code review rounds
and fixes · `ponytail-review` applied / rejected · tests and full suites (fresh output from your own run;
after a fix, which ones re-ran) · production steps left to do (the design doc's: who, where) · open
issues, and deferred findings with why.

## Gotchas
- Run long commands (full suites, builds, ≥2 parallel `<RUN_AGENT>` calls) with `run_command` in the
  background (`WaitMsBeforeAsync: 500`), output to `/tmp/team/<slug>/` (wait for automatic background task
  completion notification; don't poll).
- **Never call `invoke_subagent` inside `/team`** (not even omitting `Model`): all surveys and reviews go
  exclusively through `~/.gemini/config/skills/team/run-agent.sh` so model IDs and Vertex billing checks
  are enforced in code.
- `team-survey` has only `read_file` (no web access); `team-reviewer` has only `read_file` and
  `search_web`. Missing/broken → the review failed: say so. Never review through a write-capable agent.
- No `## Verdict:` in a reviewer's JSON response → re-invoke `<RUN_AGENT>` once with `<conversation_id>`
  requiring `## Verdict:`; still nothing → the review failed (say so). A review that lists unchecked areas
  is partial: check them yourself, never call it a full approval.
- Lost track of Orca mail? `orca orchestration inbox --terminal run:<run_id> --limit 50 --json` shows
  messages already delivered.
- Orca may inject a notice ("You have N orchestration message…") as a user turn in terminal mode. It
  isn't the user: process the message per "Orca worker" and answer briefly if still waiting on others.
