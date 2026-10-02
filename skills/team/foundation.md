# /team: foundation mode

Part of the team skill. Read it only for foundation mode or F-change. Section ids (T1–T6, C-1…)
and the Shared rules are in `~/.claude/skills/team/SKILL.md`, which is already loaded.

## F. Foundation mode

For a service designed from scratch, or a re-founding. Orca is not required (the reviewers are
subagents). Output lives in `docs/design/foundation/` and is **canonical**: feature
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
the recommended one first). The reviewers do not review the charter — these are product calls, not code.
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

### F-4. Adversarial review (T6, read-only)
T6 with the request `/tmp/team/<slug>/foundation-review-req.md`: the absolute paths of the charter,
every decision record and `slices.md`, this checklist, and the T2 output format.
- Contradictions: decision vs charter, decision vs decision, slice vs decision
- Missing expensive decisions (what would hurt to change after S3?); listed decisions that are
  actually cheap to reverse (move them into slices)
- Rewrite vs reuse, stale patterns, over-engineering against the design caps (cite them), unmeasured claims
- Does S1 (or S1a, S1b…) really touch every decision end to end? Is any slice too big for one run?

Check every item against the code and docs **yourself**, then accept (edit the doc) or rebut (with
evidence). ≤2 rounds (T6 step 3). Items still contested after 2 rounds go to the user at F-5 with
both sides' evidence.

### F-5. Foundation approval gate
```
## Foundation ready — approval requested
- Charter: docs/design/foundation/charter.md — one line: …
- Decisions (N): NNN <title> — one line each (+ what the review changed)
- Slices: S1 <walking skeleton> / S2 … / S3 … (+N more, one line each)
- Adversarial review: reviewer raised N / risk reviewer raised M → Claude accepted N / rebutted N
  (or: a review failed — why)
- Contested (your call): …
- Open questions: …
Reply "approve" to accept the foundation and start S1. Otherwise tell me what to change.
```
End your turn and wait. Approved ("approve" / "go" / "OK") → set the decision records to `accepted`, then start S1 at **C-1**:
Claude writes S1's design, runs its review and its own T3 gate. (Without Orca, the hand-off happens
after that gate, as in section 0 — never hand `slices.md` to an implementer as a design.)

### F-change. Changing the foundation
Entered two ways: a slice's design, implementation or review shows that a charter line or an accepted
decision is wrong (or needs a new expensive-to-reverse decision), or the user asks for a change
directly (`/team foundation change: …`).
1. **Stop the slice, if one is in progress.** Without Orca: ask the user to stop their `claude --model
   sonnet` session and list what it changed. In C with a worker running: reply to its pending
   question, or `orca orchestration send --to dispatch:<ctx_id> --subject "Stop" --body "<msg>" --json`
   (workers read follow-ups at their checkpoints), with "Stop: the design is changing. Don't edit
   further; send worker_done with --outcome failed and the files modified so far." Wait for
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
