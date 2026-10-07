# /team: founded services

Part of the team skill: its Rules, Orca worker commands and templates (D, R, C, S, T) are in
`SKILL.md`, already loaded. `docs/design/foundation/` is **canonical** for what gets built: design docs
cite it and never override it; it changes only through **Change**. How the team works — who
implements, approval unit, review rounds and reviewers, reports — belongs to this skill, not to the
foundation, so a skill update reaches every service.
```
docs/design/foundation/
  charter.md                what the service is — the user's decisions
  decisions/NNN-<slug>.md   one expensive-to-reverse decision each
  slices.md                 milestones, their slices, status
```

## Found
1. **Inventory**: a foundation already exists → update it, don't recreate it. Read the existing docs,
   code and infra; one canonical place per decision (extract into the foundation, leave a pointer;
   whether to edit the user's docs is a charter question). Measure what exists, read-only.
2. **Charter** (the user decides, Claude drafts; 1–2 pages):
   ```
   One line: what, for whom · Who does what: core flows · Success / failure: observable signals ·
   Design caps: the scale to hold · Not doing · Stage: pre-launch | live (live = real users or
   customer data exist) · Open questions
   ```
   Every unknown is a question, never a guessed business decision: ask in batches of up to 4
   (AskUserQuestion, recommended option first). **Gate**: show one line, caps, non-goals, open
   questions; end your turn. Go on only on "OK" / "approve" / "go".
3. **Decisions**: only what is expensive to reverse once code or data depend on it. Check: data model
   and source of truth, identity/auth, tenancy and permissions, external integrations, money and
   document flow, runtime and background work, observability. Not a decision: how the team works
   (above); a safety rule that follows from a decision is (e.g. one shared production database → trial
   every write first). One page each:
   ```
   # NNN <title>
   Status: proposed | accepted | superseded by NNN | rejected
   Context (charter lines, measured facts) · Decision · Options considered (reuse / platform primitive
   / simplest — why not) · Currency: current recommended way, dated source · Consequences ·
   Revisit when (an observable signal tied to the caps) · Not built
   ```
4. **Milestone map** → `slices.md`. A milestone is one user-visible capability made of 2–4 slices; a
   slice is what one reviewer can review in one pass (roughly ≤30 files, ≤1 hour of worker time).
   M1 is a walking skeleton: the thinnest end-to-end path touching every decision once, outside
   production. Then order by risk (least-proven decision first), then value. Per slice: goal /
   decisions / scope (modules) / definition of done / depends on / risk (money, auth, data-changing
   migration). Status `todo` → `done` (reviewed and committed); `blocked: <reason>`. Detail M1 only.
5. **Review**: reviewer + risk reviewer with template R plus: contradictions (decision vs charter,
   decision vs decision, slice vs decision); a missing expensive decision, or a cheap one listed;
   over-building against the caps; M1 really touches every decision; a slice too big. ≤2 rounds.
6. **Gate**, then end your turn:
   ```
   ## Foundation ready — approval requested
   Charter one line · decisions (one line each, + what review changed) · M1 slices, later milestones
   one line each · review: raised / accepted / rebutted · contested (your call) · open questions
   Reply "approve" and I'll propose M1, or tell me what to change.
   ```
   Approved → decisions `accepted`, then a milestone run for M1.

## Milestone run
Entered for a milestone ("M5 진행해", `/team M5`) or a slice (that slice plus its unfinished
dependencies). **The foundation wins on what to build and on the safety rules that follow from its
decisions** (extra risk areas, test and database rules). **How the team works follows this skill**: a
foundation line that sets the implementer, approval unit, review procedure or reports is not followed,
and the gate names it ("015: Claude implements → not followed: Sonnet worker") so the user can drop it
with a Change. The user saying so in the request ("you implement it") still wins.
1. **Plan** (≤10 minutes, parallel Explore agents per area): the milestone's slices not yet `done`, in
   dependency order, with ids (S<m>a, S<m>b… if missing). Slices with no dependency between them and
   no shared source files are **parallel**. A milestone design doc already exists (a stopped run) →
   re-check it against the current code; slices its `Approved:` line lists that are still valid go to
   Build with no new gate; any other slice, or a substantial change, goes through review and the gate.
2. **One milestone design doc** `docs/design/<YYYYMMDD>-m<n>-<slug>.md`: shared interfaces and
   migrations first, then template D per slice. Skip what the foundation already settled.
3. **One review** (template R; the risk reviewer if any slice is risky; a big milestone gets one
   reviewer per group of slices), ≤2 rounds.
4. **Milestone gate**, then end your turn:
   ```
   ## Milestone M<n> — approval requested
   Design doc · slices in order (parallel groups marked), one line each · shared interfaces and
   migrations · risky slices · review: raised / accepted / rebutted · each slice ends with a local
   commit of its own files (no push) · post-review steps (applying migrations…): who, where ·
   stops and asks you only for: a Critical still contested after 2 rounds, a code review not approved
   after 2 rounds, a merge conflict between parallel slices, a substantial design change, a
   foundation change, a business call, a post-review step of yours, work beyond this list
   Reply "approve" or "go", "only S<n>" for one slice, or tell me what to change.
   ```
5. **Build**, no further approvals: first add `Approved: <date> (S…)` with the approved slices to the
   design doc's header. One Orca run for the milestone.
   - Dependent slices: one Sonnet worker in the milestone worktree takes them one after another
     (`--terminal <handle>`), each with spec S naming its slice.
   - Parallel slices start once the slices they depend on are committed: one worker each, at most 3 at
     once, `worker-start --spec … --worktree new-child --name <slice-id> --base-branch <the milestone
     worktree's branch> --setup run --agent claude --model sonnet --timeout-ms 120000 --json` (Bash
     timeout ≥180000). Its code review, `git diff --stat` and definition-of-done re-run happen in its
     child path.
   - Each slice gets SKILL step 6 (code review, re-run definition of done, `ponytail-review`; a large
     diff gets one reviewer per area; fixes to the same worker). The next slice's build doesn't wait
     for this review unless it depends on that slice.
   - Approved → commit locally exactly that slice's files: the union of its dispatches'
     `--files-modified`, checked against `git status --porcelain`. In the milestone worktree the same
     commit sets its `slices.md` line to `done`. In a child: commit the slice's files there, release its
     worker, `git cherry-pick` the commit into the milestone worktree, set its `slices.md` line to
     `done`, `git add` it and `git commit --amend --no-edit`, then `orca worktree rm --worktree
     path:<child>`. A conflict → `git cherry-pick --abort` and stop.
   - Post-review steps: Claude's → run them; the user's → mark `done (apply pending: <step>)` and stop;
     on their "done", continue — no new gate.
   - Without Orca: hand the user one slice spec at a time; they come back for its review.
6. **Stopping** (only the gate's stop items): start no new worker; let running slices the stop doesn't
   touch finish review and commit; wait for running reviewers; release settled workers (never on idle);
   set the unfinished slice `blocked: <reason>` (its child worktree stays). Report with template T and
   end your turn — for a Change, its approval request (Change step 3) is the report. A code review not
   approved after round 2 stays uncommitted: the user picks one more round (a new worker in that
   slice's worktree), accept as is, or drop it (revert that slice's files; a child:
   `orca worktree rm --force`); then the run continues with no new gate.
7. **Report**: one template T for the milestone (a line per slice: files, commit, review fixes,
   tests), then the next milestone in one line. Start it only when the user says so.

**Launch**: when the user sets `Stage: live`, run one risk review of the auth, customer-data and money
code built so far (one reviewer per area), turn its findings into fix slices, and add
`launch risk review: <date>` to the charter.

## Change
Entered when a design, build or review shows a charter line or accepted decision is wrong (or a new
expensive decision is needed), or on `/team foundation change: …`.
1. A slice in progress that the change affects: `orca orchestration send --to dispatch:<ctx_id>
   --subject "Stop" --body "Stop: the design is changing. Don't edit further; send worker_done with
   --outcome failed and the files modified so far." --json`, wait for it to settle, release it (never
   on idle); set the slice `blocked: <reason>`. Without Orca, ask the user to stop their session.
2. New decision record (`proposed`) superseding the old one; a charter edit gets a dated change line.
3. Review: reviewer + risk reviewer on what the change touches, ≤2 rounds. Show it; end your turn.
4. Rejected → record `rejected`, charter edit reverted, slice back to its status. Approved → `accepted`,
   old record `superseded by NNN`; update affected `todo` slices; `done` slices built on the old
   decision get a rework slice ("S<k>: move S<n> to NNN").
5. Resume: revise the affected design-doc sections from what the worktree holds, review that change
   (≤2 rounds). Inside a milestone run the approved Change is the gate: continue at Build (a slice
   whose worker was released restarts with a new worker in its worktree). A feature shows gate G
   again.
