# tandem-skills

**Claude designs and reviews. Grok builds.** Cross-model agent-team skills for Claude Code and Grok Build.

[한국어 README](README.ko.md)

Like a tandem bicycle: one rider steers, the other pedals. Open Claude Code in your repo, type
`/team <task>`, and you get:

```
Claude drafts the design
  → Grok adversarially reviews it (reads the repo, tries to break the design)
  → Claude rebuts or accepts each point with evidence, revises the doc   (≤2 rounds)
  → ★ you approve the design ★
  → Grok implements (a supervised worker in its own terminal tab)
  → Claude reviews the diff, re-runs the tests                            (≤3 rounds)
  → Grok fixes → report
```

Starting a whole service from scratch? `/team foundation <service>` first settles the charter, the
decisions that are expensive to reverse and a slice map — then every slice runs through the loop above.

No MCP, no daemon. Two shell scripts that call `claude -p` and `grok` headlessly, plus two
`SKILL.md` files that both agents already know how to read. The default path runs Grok as an
[Orca](https://github.com/stablyai/orca) worker; without Orca, the Grok-driven fallback needs nothing
but the scripts.

## Why

Single-model agents grade their own homework. Every model has blind spots, and the cheapest way to
catch them is a *different* model with file access and an incentive to disagree. The existing
cross-model tools either give you a one-shot "second opinion" over an API (no repo access, no
back-and-forth) or need a bridge daemon for two live sessions. This sits in between: the models
argue in rounds, cite `file:line`, and a human approves the design before any code is written.

Claude drives by default because design is where it matters most which environment the designer
runs in: an interactive Claude Code session has your MCP servers, web search, project memory, and
you — to answer questions and approve. A headless design call has no web search and no one to ask,
and reaches only what your permission settings allow.

## What's inside

| Skill | Who drives | What it does |
|---|---|---|
| `/team` | Claude (or Grok) | Feature mode: the design → adversarial review → approval → implement → code review loop above. Foundation mode: charter → decision records → slice map → adversarial review → approval, before the first slice |
| `/debate` | Claude | Claude drafts, Grok criticizes in rounds (read-only), Claude verifies each point against the code and reports the consensus. Used stand-alone for design decisions. `/team` reuses its `grok-turn.sh` (with its own review format) for every adversarial review Claude drives |

Both skills work in either direction because **Grok Build reads `~/.claude/skills/`** (and
`~/.claude/CLAUDE.md`) natively — verified with `grok inspect`.

## Requirements

- [Claude Code](https://code.claude.com) ≥ 2.1 (`claude` on PATH, logged in)
- [Grok Build](https://x.ai/cli) ≥ 1.0 (`grok` on PATH, logged in)
- `jq`, `git`, and `uuidgen` (or python3)
- [Orca](https://github.com/stablyai/orca) for the default feature path, where Grok runs as a
  supervised Orca worker with a visible terminal tab. Foundation mode and the Grok-driven fallback
  work without it.

Tested with Claude Code 2.1.273–2.1.280 (Claude Opus 5) and Grok Build 1.0.30–1.0.40 on macOS.

## Install

```bash
git clone https://github.com/sungminpark-biz/tandem-skills.git
cd tandem-skills && ./install.sh          # copies skills/ into ~/.claude/skills/
# or: ./install.sh --link          # symlink, so `git pull` updates in place
```

Check:
```bash
grok inspect        # Skills: team, debate  [claude]
claude              # type /team or /debate
```

## Usage

### Feature (the default)

Inside an Orca worktree, in Claude Code:

```
/team Add refresh-token rotation to the auth service
```

Claude will:
1. write `docs/design/<date>-<slug>.md` (scope, signatures, order, definition of done, what is deliberately not built)
2. get Grok's adversarial review via `grok-turn.sh` (critical / missing / ambiguous, with evidence), check each item against the code, and revise the doc or rebut
3. **stop and show you a summary — nothing is implemented until you say "approve"**
4. spawn Grok as an Orca orchestration worker (`worker-start --agent grok`) and answer its questions
5. review the diff, re-run the tests, and dispatch fixes to the same worker until approved (max 3 rounds)
6. report: what the review changed, files touched, tests, cost

No Orca? Claude still does steps 1–3, then tells you to run `/team implement <design doc>` in Grok Build.

Optional: with the [ponytail](https://github.com/DietrichGebert/ponytail) plugin installed, step 5 also
runs its `ponytail-review` on the diff — an over-engineering delete-list that Claude filters before
passing it to Grok. Keep ponytail's always-on mode off (`~/.config/ponytail/config.json`:
`{"defaultMode": "off"}`); the team skill never invokes the main `ponytail` skill.

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
4. get Grok's adversarial review of the whole foundation (contradictions, missing or misplaced
   decisions, over-engineering against the design caps)
5. **stop for your approval**, then run S1 as a normal feature

Foundation docs are canonical: feature designs cite them and never override them. If a slice proves a
decision wrong, the slice stops, a superseding decision record is written, reviewed and approved, and
then the slice resumes.

### Grok-driven (fallback)

In any git repository, open Grok Build and:

```
/team Add refresh-token rotation to the auth service
```

Grok calls Claude headlessly (`claude-turn.sh`; only `docs/design/**` is writable, not `docs/design/foundation/`) for the design, reviews
it adversarially itself, sends the review back to Claude, stops for your approval, implements, and asks
Claude to review the diff until `APPROVE`.

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

The scripts don't rely on the model promising to behave:

| Mode | Permission | Effect |
|---|---|---|
| `claude-turn.sh design` | `--permission-mode dontAsk` + `Write(docs/design/**)`, `Edit(docs/design/**)` (except `docs/design/foundation/**`), no Bash allow rules, mutating git/shell commands denied | Claude can write the design doc and nothing else. Bash runs only what Claude Code classifies as read-only — `git stash`, `git branch`, `touch`, `>` redirects are refused |
| `claude-turn.sh review` | `dontAsk` + `Bash` allowed, `Write`/`Edit` and `git commit/checkout/reset`, `rm`, `mv`, `sed -i`… denied | Claude can run the tests but not change files |
| `grok-turn.sh` | `--permission-mode plan` | Grok is read-only |
| Approval gates | skill rule | The driver must end its turn and wait after the design (and the foundation) is final |

Other details that came out of real runs:
- Session ids are chosen **before** launch and written next to the prompt file (`/tmp/team/<slug>/last-claude-session`, `/tmp/team/<slug>/last-grok-session`), so a killed or timed-out call can be resumed with its exploration intact, and concurrent runs never overwrite each other's.
- Hitting the turn limit (`error_max_turns` for Claude, `"maxTurns": true` for Grok) → resume the same session, never start over.
- Design prompts say "write the skeleton first, then fill in" and cap tool calls — Opus at high effort will otherwise explore for 20+ minutes before writing a word.
- In the Grok-driven path, the same Claude session is resumed for the design revision and every code review, so the reviewer remembers the design it wrote.

## Cost and time (from real runs)

Phase 1 of a new Next.js customer app (30 files, 7 test files, 23 tests), Grok-driven:
Claude ≈ $7 total across design + 2 review rounds (Opus 5, including one timed-out design attempt), Grok ≈ 55 min of wall time. Design calls for a large scope take 20–40 minutes.
A Grok adversarial review turn costs roughly $0.25–0.4.

## Limitations

- Grok does **not** get Claude's project memory; only `CLAUDE.md`. That's why design and review are Claude's job.
- Allow rules in your own Claude Code settings still apply to the headless calls (`dontAsk` only refuses what nothing allows). The scripts' deny lists override them for the commands they name — check your user settings for allows that reach production (e.g. `kubectl exec`).
- The review-mode Bash denylist is not exhaustive (`>` redirects, `python -c` can still write). It's a second line of defense behind the prompt, not a sandbox.
- Approval gates are a model-compliance property, not a hard block.
- The default feature path needs Orca. Foundation mode and the Grok-driven fallback work anywhere.
- Foundation mode is new and has not had a full run yet — watch the first one.
- In Claude-driven runs a Grok worker can stall on its own edit-approval prompt; the skill tells Claude how to release it, but watch the tab.

## Layout

```
skills/
  team/SKILL.md          the workflow (0: mode and path, F: foundation, C: Claude-driven, G: Grok-driven)
  team/claude-turn.sh    headless Claude: design | review   (Grok-driven path)
  debate/SKILL.md        the debate loop
  debate/grok-turn.sh    headless Grok: read-only critic     (every adversarial review Claude drives)
install.sh
```

## License

MIT
