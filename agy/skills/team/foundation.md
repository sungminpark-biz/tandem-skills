# /team: founded services

Part of the team skill: its Model & Role Matrix, unconditional 100% Vertex Credit Billing rule, Rules,
`<RUN_AGENT>` (`~/.gemini/config/skills/team/run-agent.sh`), Orca worker commands and templates (D, R, C,
S, T) are in `SKILL.md`, already loaded. `docs/design/foundation/` is **canonical** for what gets built:
design docs cite it and never override it; it changes only through **Change**. How the team works — who
implements and on which Vertex Gemini 4 tier, parallel fan-out, approval unit, review rounds and reviewer
models, how often and how widely tests run, reports — belongs to this skill, not to the foundation, so a
skill update reaches every service.
```
docs/design/foundation/
  charter.md                what the service is — the user's decisions
  decisions/NNN-<slug>.md   one expensive-to-reverse decision each
  slices.md                 milestones, their slices, status
```

## Found
1. **Inventory**: run `SKILL.md` Preflight first (`<RUN_AGENT> --preflight`). A foundation already exists
   → update it, don't recreate it. Read the existing docs, code and infra (parallel `<RUN_AGENT>
   gemini-4-hydrogen-high team-survey` runs when broad; direct reads when narrow); one canonical place per
   decision (extract into the foundation, leave a pointer; whether to edit the user's docs is a charter
   question). Measure what exists, read-only.
2. **Charter** (the user decides, the Carbon coordinator drafts; 1–2 pages) plus candidate milestones as
   user-visible capabilities, by SKILL Rules: Product plan with these sections instead of template P's
   (an existing charter: only the changes; `Stage` and caps are questions unless measured):
   ```
   One line: what, for whom · Who does what: core flows · Success / failure: observable signals ·
   Design caps: the scale to hold · Not doing · Stage: pre-launch | live (live = real users or
   customer data exist — in this service, or in another product on its database) · Open questions
   ```
   Every unknown is a question, never a guessed business decision: ask in batches of up to 4
   (`ask_question` tool, recommended option first). **Gate**: show one line, caps, non-goals, candidate
   milestones, open questions; end your turn. Go on only on "OK" / "approve" / "go".
3. **Decisions**: only what is expensive to reverse once code or data depend on it. Check: data model
   and source of truth, identity/auth, tenancy and permissions, external integrations, money and
   document flow, runtime and background work, observability. Not a decision: how the team works
   (above); a safety rule that follows from a decision is. Before launch (SKILL Rules) the data is test
   data: a safety rule stays only where a mistake reaches users, money, secrets or an external service
   (messages, paid APIs); everywhere else take the cheaper option and write `Revisit when: launch`
   (e.g. one shared database before launch → apply and fix forward, no trial runs). One page each:
   ```
   # NNN <title>
   Status: proposed | accepted | superseded by NNN | rejected
   Context (charter lines, measured facts) · Decision · Options considered (reuse / platform primitive
   / simplest / what today's search found — why not) · Currency: searched, not recalled — sources with
   dates · Consequences (a safety rule: its estimated cost per slice, and the cheaper option) ·
   Revisit when (an observable signal tied to the caps) · Not built
   ```
4. **Milestone map** → `slices.md`, from the candidate milestones approved with the charter, ordered as
   below; the foundation gate names any merged, split, dropped or added. A milestone is one user-visible
   capability made of 2–6 slices; a slice is what one reviewer can review in one pass (roughly ≤30
   files, ≤1 hour of worker time).
   **Shape every milestone for parallel worker fan-out:** isolate shared schemas, migrations and
   cross-slice contracts into a thin initial slice (`S<m>a`), then split independent capability/module
   work into disjoint-file slices (`S<m>b`, `S<m>c`, `S<m>d`…) so they build concurrently in parallel
   child worktrees as soon as `S<m>a` commits.
   M1 is a walking skeleton: the thinnest end-to-end path touching every decision once, outside
   production. Then order by risk (least-proven decision first), then value. Per slice: goal / decisions
   / scope (modules & disjoint files) / definition of done (SKILL Rules: Tests) / depends on / risk &
   worker tier (`gemini-4-hydrogen-xhigh` default, or `gemini-4-carbon-medium` when hitting SKILL's
   Hard/Risk bar: money, auth, concurrency/locks, or data-changing migration except before launch). Status
   `todo` → `done` (reviewed and committed); `blocked: <reason>`. Detail M1 only.
5. **Review**: write `/tmp/team/<slug>/ls-files.txt` (if code exists) and request files, then run parallel
   reviewer + risk reviewer via `<RUN_AGENT> gemini-4-carbon-medium team-reviewer` (`WaitMsBeforeAsync:
   500`, in one turn) with template R plus: contradictions (decision vs charter, decision vs decision,
   slice vs decision); a missing expensive decision, or a cheap one listed; over-building against the
   caps; a safety rule whose cost the stage doesn't justify; M1 really touches every decision; a slice too
   big or needlessly serialized when a thin `S<m>a` contract slice would unlock parallel slices. Round 2
   via `<RUN_AGENT> ... <conversation_id>`. ≤2 rounds.
6. **Gate**, then end your turn:
   ```
   ## Foundation ready — approval requested
   Charter one line · decisions (one line each, + what review changed) · M1 slices (parallel groups &
   worker tiers), later milestones one line each (candidate milestones merged, split, dropped or added,
   and why) · review: raised / accepted / rebutted · contested (your call) · open questions
   Reply "approve" and I'll propose M1, or tell me what to change.
   ```
   Approved → decisions `accepted`, then a milestone run for M1.

## Milestone run
Entered for a milestone ("M5 진행해", `/team M5`) or a slice (that slice plus its unfinished
dependencies). **The foundation wins on what to build and on the safety rules that follow from its
decisions** (extra risk areas, database rules, what a test must check). **How the team works follows
this skill (including unconditional 100% Vertex Credit Billing)**: a foundation line that sets the
implementer (e.g. Claude/Codex), approval unit, review procedure, test runs or reports is never followed.
Before launch, neither is a safety rule that guards only test data (not users, money, secrets or external
services). The gate names each such line ("015: Claude implements → not followed: Orca worker
`antigravity · gemini-4-hydrogen-xhigh` / `gemini-4-carbon-medium` (100% Vertex credits)"; a safety rule
with its cost per slice) and the milestone design doc records it; the user may keep a non-billing process
rule by saying so, or drop it for good with a Change (non-Vertex billing is never enabled). The user
saying "you implement it" in the request still wins.
1. **Plan** (≤10 minutes, `SKILL.md` Preflight first, then parallel `<RUN_AGENT> gemini-4-hydrogen-high
   team-survey` per area when broad, plus SKILL step 1's coordinator `search_web` when a slice picks
   something new, then the product plan (SKILL Rules) for the milestone's capability when users see it and
   no milestone design doc has one yet): the milestone's slices not yet `done`, in dependency order, with
   ids (S<m>a, S<m>b… if missing) and each slice's worker model (`gemini-4-hydrogen-xhigh` default;
   `gemini-4-carbon-medium` if the slice hits SKILL's Hard/Risk bar). **Maximize parallelism**: slices
   with no dependency between them and no shared source files are **parallel** (if two slices only collide
   on a small shared type/migration, pull that contract into an earlier thin slice so both run in
   parallel). A milestone design doc already exists (a stopped run) → re-check it against the current
   code; slices its `Approved:` line lists that are still valid go to Build with no new gate; any other
   slice, or a substantial change, goes through review and the gate.
2. **One milestone design doc** `docs/design/<YYYYMMDD>-m<n>-<slug>.md` (let `<m-slug>` be `m<n>-<slug>`):
   the product plan (template D's line, once for the milestone; the slices' D leave it out), shared
   interfaces and migrations first, then template D per slice (including each slice's Worker tier and
   disjoint file list — none touching `docs/design/`), then the full-suite commands, Production steps and
   a Deferred section for the milestone's end, and the foundation lines it doesn't follow. Skip what the
   foundation already settled.
3. **One design review** (write `ls-files.txt` and `grep -rn` files to `/tmp/team/<m-slug>/`, then run
   `<RUN_AGENT> gemini-4-carbon-medium team-reviewer` with template R; add the parallel
   `gemini-4-carbon-medium` risk reviewer with `WaitMsBeforeAsync: 500` if any slice is risky; a big
   milestone gets one `gemini-4-carbon-medium` reviewer per group of slices; Round 2 via
   `<conversation_id>` per SKILL Rules), ≤2 rounds.
4. **Milestone gate**, then end your turn:
   ```
   ## Milestone M<n> — approval requested
   Design doc · product plan: its assumptions, or none (why) · implementer per slice (exact
   `antigravity · gemini-4-hydrogen-xhigh` default, Hard/Risk slices `antigravity ·
   gemini-4-carbon-medium` with reason — 100% Vertex credits; you may change any slice's allowed
   `gemini-4-*` tier here) · slices in order (parallel fan-out waves marked), one line each · shared
   interfaces and migrations · risky slices · review: raised / accepted / rebutted / deferred · repo lines
   not followed (foundation, GEMINI.md, CLAUDE.md, guides), and why · design doc committed first, then
   each slice ends with a local commit of its own files (no push; a fix from the full suites, an `after`
   command or the milestone review gets one more) · full suites and a Carbon milestone review at the end ·
   post-review steps (applying migrations…): who, where ·
   stops and asks you only for: a Critical still contested after 2 rounds, a code review (a slice's or
   the milestone review's) not approved after 2 rounds, a merge conflict between parallel slices,
   full suites or an `after` command still failing after one fix, a substantial design change, a
   foundation change, a business call, a post-review step of yours, work beyond this list
   Reply "approve" or "go", "only S<n>" for one slice, or tell me what to change.
   ```
5. **Build (Streaming Parallel DAG)**, no further approvals:
   - **Commit design doc first so the milestone worktree stays clean**: record `Base: <HEAD before this
     commit>` (a resumed run keeps its existing `Base:`) and `Approved: <date> (S…)` in
     `docs/design/<YYYYMMDD>-<m-slug>.md`, then commit that design doc locally once on the milestone
     branch (`git add docs/design/<YYYYMMDD>-<m-slug>.md && (git diff --cached --quiet || git commit -m
     "docs(m<n>): approve milestone design")`). This ensures child worktrees inherit the design doc,
     `git diff <Base>..HEAD` includes it, and no dirty tracked file ever blocks `git cherry-pick`!
   - Create one Orca Run (`orca orchestration run-create --objective "M<n>: <title>" --json`).
   - **Single ready slice (no other slice ready in parallel)**:
     - Start in `--worktree current --agent antigravity --model <slice_model> --timeout-ms 120000 --json`
       and end your turn until Orca wakes you.
     - Once reviewed and locally committed, if the next step is a **single** dependent slice using the
       **same `--model`**, send its spec via `orca orchestration send --to dispatch:<dispatch_id>
       --subject "Slice <next-id>" --body "Read and implement /tmp/team/<m-slug>/spec-<next-id>.md"
       --json`. If the next step uses a different `--model` or fans out into ≥2 parallel slices, release
       the settled worker (`orca orchestration worker-release --dispatch <dispatch_id> --json`) before
       starting the new worker(s).
   - **Parallel slices (≥2 slices ready at once — up to 5 concurrent child worktrees)**:
     - Launch all ready slices (up to **5 at once**) in **one turn**, each in `--worktree new-child --name
       <m-slug>-<slice-id> --base-branch <milestone-branch> --setup run --agent antigravity --model
       <gemini-4-hydrogen-xhigh | gemini-4-carbon-medium> --timeout-ms 120000 --json` so the milestone
       worktree stays clean for streaming `git cherry-pick`; then **end your turn** (no polling).
   - **Streaming per-slice review**: as **each** slice settles (`worker_done`), immediately run `SKILL.md`
     Step 6 (`git status --porcelain -uall` scope check + `git add -N` + `<RUN_AGENT>
     gemini-4-hydrogen-high team-reviewer` + parallel `gemini-4-carbon-medium` risk reviewer if risky +
     `ponytail-review` + narrow DoD + fix/Round-2 rules) in that slice's worktree without waiting for
     slower sibling slices.
   - **Approved slice commit & streaming unblock**: commit locally **only** that slice's assigned files
     (verified via `git status --porcelain -uall`).
     - In the milestone worktree: stage the slice's files, its `slices.md` `done` update, and any
       `Deferred` addition in the milestone design doc together in one commit.
     - In a child worktree: commit the slice's files there, release its worker (`orca orchestration
       worker-release --dispatch <dispatch_id> --json`), `git cherry-pick` that commit into the clean
       milestone worktree (conflict → `git cherry-pick --abort` and stop), update `slices.md` (`done`) and
       any `Deferred` note in the milestone design doc, `git add` them and `git commit --amend --no-edit`,
       then `orca worktree rm --worktree path:<child>`.
   - **Post-review steps & dependency gate**: the coordinator's → run them, then the commands marked
     `after <step>`; the user's → set `slices.md` to `done (apply pending: <step>)` in that commit and
     stop (`done (apply pending: …)` does **not** satisfy `depends on` — dependent slices wait until the
     user replies "done", the `after <step>` commands pass, and `slices.md` is committed as plain `done`).
     Right after a slice reaches plain `done`, if any queued slice now has every dependency at plain
     `done` (and active workers < 5), launch it immediately before ending your turn!
   - **End of the run, every approved slice at plain `done`**: the coordinator starts the full suites once
     (`run_command` in the background when long-running) and — when every slice of the milestone is now
     `done` (a partial run leaves it to the run that finishes the milestone) — runs the **milestone
     review**: write `git diff <Base>..HEAD`, `git ls-files --cached --others --exclude-standard | sed
     "s|^|$PWD/|"`, and `grep -rn` of the names the milestone changed to `/tmp/team/<m-slug>/`, then run
     parallel `<RUN_AGENT> gemini-4-carbon-medium team-reviewer` calls
     (`WaitMsBeforeAsync: 500` in one turn), one per area — one for ≤30 files, else up to 3 (e.g. data and
     server code; screens and tests; docs and production steps) — with the prompt below. No separate risk
     reviewer: the data and server Carbon reviewer also reads the risky slices for that risk. Check each
     reviewer's findings against the code as it returns. Once the suites have finished too, one fix round
     takes the accepted findings, those marked `→ milestone fix` and suite failures that need a fix (SKILL
     Rules: Tests): launch a worker in the milestone worktree (`gemini-4-carbon-medium` if any fix touches
     a risky area, concurrency, or cross-slice invariant; else `gemini-4-hydrogen-xhigh`), told which
     files the fixes may touch (the doc's Scope doesn't limit it); run `git add -N` on any new files, run
     Round 2 via `<RUN_AGENT> ... <conversation_id>` on the milestone reviewers whose findings it fixes —
     the rest of it (`→ milestone fix` items, suite fixes) goes to the milestone reviewer of its area, or,
     in a run without a milestone review, to a `gemini-4-hydrogen-high` template C reviewer (+
     `gemini-4-carbon-medium` risk reviewer if risky) — and `ponytail-review` runs on its diff; then one
     local commit, which deletes the `→ milestone fix` items it fixed from `Deferred`, and re-run what
     SKILL Rules: Tests names. Doc-only fixes the coordinator makes itself, in the same commit, re-checked
     via `<conversation_id>` by the reviewers whose findings they fix; a foundation line changes here only
     to apply an `accepted` decision record (anything else: Change).
     ```
     The finished milestone, reviewed whole: worktree <path>, diff <its file> and file list <its file>,
     design doc <path> (its Deferred section too), docs/design/foundation/. Slice reviews and passing
     tests are not evidence: check afresh. Your area: <area>; read outside it only to follow a rule or
     data it sets or changes. No tests, not even to check one thing: the full suites are running.
     ## Verdict: APPROVE | REQUEST_CHANGES
     ## Findings — most severe first: file:line, what is wrong, a real failure (input or state →
     wrong result), evidence; a design line that fails is a finding; unverified → say so
     ## Between slices — a rule one slice sets that another breaks; code, screens or jobs that read or
     write what the milestone changed but no slice touched
     ## Design vs build — missing or built differently: justified or not
     ## Deferred — in your area, each deferred item that should have been fixed: it can lose real
     data (not test data) or money, do something that can't be undone, cut someone off, or show a
     real person something false ("this slice doesn't touch X" is no reason); skip items marked
     `→ milestone fix`
     <one reviewer only — the docs area, or the only reviewer:>
     ## Production steps — what the built code needs to work in production (settings, secrets,
     schedulers, external setup), steps carried over in earlier design docs (docs/design/) included:
     each in this design doc's Production steps?
     ## Stale docs — CLAUDE.md, GEMINI.md, AGENTS.md, README, foundation lines this milestone made wrong
     ## Not checked
     Review only: no edits, no DB/MCP writes, no deploys, no tests (the coordinator runs them). Stop
     after 60 tool calls and list what you didn't check.
     ```
   - Without Orca: hand the user one slice spec at a time; they come back for its review.
6. **Stopping** (only the gate's stop items): start no new worker; let running slices the stop doesn't
   touch finish review and commit; wait for running reviewers; release settled workers (never on silence
   or idle alone); set the unfinished slice `blocked: <reason>` (commit that `slices.md` update if the
   milestone worktree is otherwise clean; its child worktree stays). Report with template T and end your
   turn — for a Change, its approval request (Change step 3) is the report. A code review not approved
   after round 2 stays uncommitted: the user picks one more round (a new `gemini-4-carbon-medium` worker
   in that slice's worktree after releasing the prior dispatch), accept as is, or drop it (revert that
   slice's files; a child: `orca worktree rm --worktree path:<child> --force`); then the run continues
   with no new gate. The milestone review's fix not approved after round 2 stays uncommitted and every
   slice stays `done`: the user picks one more round, accepts it as is, or drops it (revert the fix's
   files; its `→ milestone fix` items become `dropped by the user`, named first in the report). Full
   suites or an `after` command still failing: committed slices stay `done`; the user picks one more fix
   round or accepts it as is (the report names the failing tests).
7. **Report**: one template T for the milestone (Vertex billing check, then a line per slice: worker
   model, parallel wave, files, commit, review fixes, tests; then the full suites and the Carbon milestone
   review: raised / fixed / rebutted / deferred and why), then the next milestone in one line. Start it
   only when the user says so.

**Launch**: when the user sets `Stage: live`, run one **`gemini-4-carbon-medium`** risk review via
`<RUN_AGENT>` of the auth, customer-data and money code built so far (one parallel reviewer per area),
turn its findings into fix slices, propose a Change for the safety rules marked `Revisit when: launch` or
recorded in design docs as not followed before launch, turn design docs' `Deferred` items that only test
data made safe into fix slices, and add `launch risk review: <date>` to the charter.

## Change
Entered when a design, build or review shows a charter line or accepted decision is wrong (or a new
expensive decision is needed), or on `/team foundation change: …`.
1. A slice in progress that the change affects: `orca orchestration send --to dispatch:<dispatch_id>
   --subject "Stop" --body "Stop: the design is changing. Don't edit further; send worker_done with
   --outcome failed and the files modified so far." --json`, end your turn until it settles, then release
   it (`orca orchestration worker-release --dispatch <dispatch_id> --json`; never on idle alone); set the
   slice `blocked: <reason>`. Without Orca, ask the user to stop their session.
2. New decision record (`proposed`) superseding the old one; a charter edit gets a dated change line
   (the Carbon coordinator drafts both; the user decides).
3. Review: parallel reviewer + risk reviewer (`<RUN_AGENT> gemini-4-carbon-medium team-reviewer` for both,
   `WaitMsBeforeAsync: 500`) on what the change touches, ≤2 rounds (Round 2 via `<conversation_id>`). Show
   it; end your turn.
4. Rejected → record `rejected`, charter edit reverted, slice back to its status. Approved → `accepted`,
   old record `superseded by NNN`; update affected `todo` slices; `done` slices built on the old
   decision get a rework slice ("S<k>: move S<n> to NNN").
5. Resume: revise the affected design-doc sections from what the worktree holds, review that change via
   `<RUN_AGENT> gemini-4-carbon-medium team-reviewer` (≤2 rounds), and commit the updated design doc on
   the milestone branch if inside a milestone run. Inside a milestone run the approved Change is the gate:
   continue at Build (a slice whose worker was released restarts with a new worker in its worktree). A
   feature shows gate G again.
