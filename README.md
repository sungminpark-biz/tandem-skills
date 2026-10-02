# tandem-skills

**Claude designs and reviews. A Sonnet worker builds.** Agent-team skills for Claude Code.

[한국어 README](README.ko.md)

Like a tandem bicycle: one rider steers, the other pedals. Open Claude Code in your repo, type
`/team <task>`, and you get:

```
Claude drafts the design
  → a read-only Claude reviewer tries to break it (reads the repo, cites file:line);
     a second, risk-focused reviewer joins for payments, DB migrations, customer data and auth
  → Claude rebuts or accepts each point with evidence, revises the doc   (≤2 rounds)
  → ★ you approve the design ★
  → a Claude Sonnet worker implements (a supervised Orca worker in its own terminal tab)
  → the reviewer checks the diff against the design, Claude re-runs the tests,
     ponytail-review hunts over-engineering                              (≤3 rounds)
  → the same worker fixes → report
```

Starting a whole service from scratch? `/team foundation <service>` first settles the charter, the
decisions that are expensive to reverse and a slice map — then every slice runs through the loop above.

No MCP, no daemon, no scripts: two `SKILL.md` files and one reviewer subagent. The implementer runs as
an [Orca](https://github.com/stablyai/orca) worker; without Orca, you implement the approved design in
`claude --model sonnet` and come back for the review.

> Earlier versions paired Claude with Grok (Grok implemented and cross-reviewed). That setup is in the
> git history up to `5e159ff`.

## Why

An agent that designs, builds and grades its own work in one context finds few of its own mistakes.
This splits the roles: the driver (your interactive Claude Code session, with your MCP servers, web
search, project memory — and you) designs; a reviewer with a fresh context, no edit rights and an
explicit job to disagree attacks the design; you approve it before any code is written; a separate
worker implements it; and the code is checked against the design by a reviewer on a different model
from the one that wrote it.

## What's inside

| Skill | What it does |
|---|---|
| `/team` | Feature mode: the design → adversarial review → approval → implement → code review loop above. Foundation mode: charter → decision records → slice map → adversarial review → approval, before the first slice |
| `/debate` | Claude drafts, a read-only critic on a different model (Sonnet when the driver is Opus) attacks it in rounds, Claude verifies each point against the code and reports the consensus. Used stand-alone for design decisions |

## Requirements

- [Claude Code](https://code.claude.com) ≥ 2.1 (`claude` on PATH, logged in)
- [ponytail](https://github.com/DietrichGebert/ponytail) in Claude Code — `/team` refuses to start
  without it (see Install)
- [Orca](https://github.com/stablyai/orca) for the implementation step, where the Sonnet worker runs
  as a supervised Orca worker with a visible terminal tab. Design, review and foundation mode work
  without it.
- Recommended: the [context7](https://github.com/upstash/context7) plugin, for the design's currency
  check (`/plugin install context7@claude-plugins-official`, then log in once with `/mcp`)

Tested with Claude Code 2.1.273–2.1.286 (Claude Opus 5 / 5.5 driver, Sonnet 5.5 workers) and Orca
1.4.204–1.4.215 on macOS.

## Install

```bash
git clone https://github.com/sungminpark-biz/tandem-skills.git
cd tandem-skills && ./install.sh          # copies skills/ into ~/.claude/skills/ and the
                                          # team-reviewer subagent into ~/.claude/agents/
# or: ./install.sh --link          # symlink, so `git pull` updates in place
```

ponytail (required) — two separate prompts in Claude Code:
```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```

Check: open a new Claude Code session and type `/team` or `/debate`.

## Usage

### Feature (the default)

Inside an Orca worktree, in Claude Code:

```
/team Add refresh-token rotation to the auth service
```

Claude will:
1. write `docs/design/<date>-<slug>.md` (scope, signatures, order, definition of done, what is deliberately not built)
2. get an adversarial review from the read-only `team-reviewer` subagent (critical / missing /
   ambiguous, with evidence) — plus a risk reviewer for payments, DB schema/migrations, customer data
   and auth — check each item against the code, and revise the doc or rebut
3. **stop and show you a summary — nothing is implemented until you say "approve"**
4. spawn a Claude Sonnet worker in Orca (`worker-start --spec … --agent claude --model sonnet`), which
   writes the code with ponytail inside the design's scope, and answer its questions
5. review the diff (a spec check: missing, unrequested, implemented-but-wrong, each quoting the
   design), re-run every test itself rather than trusting the worker's report, run `ponytail-review`,
   and dispatch fixes to the same worker until approved (max 3 rounds)
6. report: what the review changed, files touched, tests

A feature that splits cleanly can run as parallel chunks — one Sonnet worker per chunk, with the files
each owns and the contract between them in the design doc. Say "you implement it" and Claude writes the
code itself instead of a worker; the review step stays the same. `sonnet` is an alias, so the worker
follows the newest Sonnet.

No Orca? Claude still does steps 1–3, then tells you to implement the design in
`claude --model sonnet` and come back for the review.

ponytail is part of the workflow: its ladder (needed at all? → reuse → stdlib → native → one line)
shapes what the design proposes and how the code is written, and its `ponytail-review` delete-list
runs in every code review, filtered by Claude. Its always-on mode can stay on; where it clashes with
the team process, the team rules win — every design-doc section is written in full, approval gates are
never skipped, and the implementer asks before cutting anything the design specifies.

### Foundation (a service from scratch)

In Claude Code:

```
/team foundation B2B wholesale marketplace where sellers and buyers trade over their own messengers
```

Claude will:
1. draft `docs/design/foundation/charter.md` with you — who, core flows, success/failure signals,
   design caps, non-goals. Every unknown becomes a question for you; business calls are yours
2. write one record per expensive-to-reverse decision (`decisions/NNN-<slug>.md`: data model,
   identity, integrations, money flow, runtime…) with the options it rejected and a dated source
3. write `slices.md`: S1 is a walking skeleton that touches every decision end to end, then slices
   ordered by risk, each small enough for one feature run
4. get the reviewer's and the risk reviewer's adversarial review of the whole foundation
   (contradictions, missing or misplaced decisions, over-engineering against the design caps)
5. **stop for your approval**, then run S1 as a normal feature

Foundation docs are canonical: feature designs cite them and never override them. If a slice proves a
decision wrong, the slice stops, a superseding decision record is written, reviewed and approved, and
then the slice resumes.

### Just a debate

```
/debate Should we move session storage from Redis to Postgres?
```

## Design quality bar

The design step is held to four rules, and the adversarial review checks each of them:
reuse before rewrite (inventory existing assets first), current as of today's date (cite the
platform's current recommendation; prefer platform primitives over hand-rolled auth/queues/cron),
measured not guessed (read-only DB/infra numbers; a new service uses its charter's design caps), and
no over-engineering (every component justified against measured scale; the doc lists what was
deliberately not built).

## How the safety works

| Piece | Mechanism | Effect |
|---|---|---|
| Reviewers and the debate critic | `team-reviewer` subagent: `Write`, `Edit`, `NotebookEdit` disallowed | They read the repo and run read-only commands; they can't edit files |
| Worker | Orca worker spec: the design's scope of change, "do not commit", questions through Orca's `ask` | Changes stay inside the approved scope, uncommitted, for review |
| Approval gates | skill rule | The driver must end its turn and wait after the design (and the foundation) is final |

Other details that came out of real runs:
- Design prompts say "write the skeleton first, then fill in" and cap tool calls — Opus at high
  effort will otherwise explore for 20+ minutes before writing a word.
- The reviewer is a custom subagent, not the built-in `Plan` agent: `Plan` is one-shot (no agent ID),
  so a second review round can't reach it, and it skips `CLAUDE.md`.
- Orca types its `You have N orchestration message…` notices into the driver's terminal as user turns;
  the skill tells the driver to keep answering in your language.

## Limitations

- Reviewer, critic and worker are all Claude models. The code review crosses models (Opus reviews
  Sonnet's code), but there is no other vendor's view any more.
- The reviewer's Bash isn't sandboxed; "review only, no writes to databases or external services" is a
  prompt rule. Check your Claude Code allow rules for anything that reaches production.
- Approval gates are a model-compliance property, not a hard block.
- The implementation step needs Orca. Design, review and foundation mode work anywhere.
- Foundation mode is new and has not had a full run yet — watch the first one.
- A worker can park on a prompt only a human can answer (plan-mode entry, a question card). The skill
  detects it through `worker-show`'s `agentWait` and answers it, but watch the tab.
- A Claude (Sonnet) worker started in a folder Claude Code hasn't trusted yet exits at the trust
  prompt, which defaults to "No, exit". Workers in the driver's own worktree are fine; for other
  placements, open `claude` there once first.

## Layout

```
skills/
  team/SKILL.md          the workflow (0: mode and path, shared rules and templates, C: feature mode)
  team/foundation.md     F: foundation mode   (read only when that path is taken)
  debate/SKILL.md        the debate loop
agents/
  team-reviewer.md       read-only, resumable reviewer / critic subagent for /team and /debate
install.sh
```

## License

MIT
