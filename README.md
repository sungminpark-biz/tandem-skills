# tandem-skills

**Claude designs and reviews. Grok builds.** Cross-model agent-team skills for Claude Code and Grok Build.

[한국어 README](README.ko.md)

Like a tandem bicycle: one rider steers, the other pedals. Open a single Grok Build session in your
repo, type `/team <task>`, and you get:

```
Claude drafts the design
  → Grok adversarially reviews it (reads the repo, tries to break the design)
  → Claude rebuts or accepts each point with evidence, revises the doc   (≤2 rounds)
  → ★ you approve the design ★
  → Grok implements
  → Claude reviews the diff, re-runs the tests                            (≤3 rounds)
  → Grok fixes → report
```

No orchestration server, no MCP, no daemon. Two shell scripts that call `claude -p` and `grok -p`
headlessly, plus two `SKILL.md` files that both agents already know how to read.

## Why

Single-model agents grade their own homework. Every model has blind spots, and the cheapest way to
catch them is a *different* model with file access and an incentive to disagree. The existing
cross-model tools either give you a one-shot "second opinion" over an API (no repo access, no
back-and-forth) or need a bridge daemon for two live sessions. This sits in between: the models
argue in rounds, cite `file:line`, and a human approves the design before any code is written.

## What's inside

| Skill | Who drives | What it does |
|---|---|---|
| `/team` | Grok (or Claude) | The full design → adversarial review → approval → implement → code review loop above |
| `/debate` | Claude | Claude drafts, Grok criticizes in rounds (read-only), Claude verifies each point against the code and reports the consensus. Used stand-alone for design decisions, or by `/team` for the adversarial review when Claude is driving |

Both skills work in either direction because **Grok Build reads `~/.claude/skills/`** (and
`~/.claude/CLAUDE.md`) natively — verified with `grok inspect`.

## Requirements

- [Claude Code](https://code.claude.com) ≥ 2.1 (`claude` on PATH, logged in)
- [Grok Build](https://x.ai/cli) ≥ 1.0 (`grok` on PATH, logged in)
- `jq`, `git`
- Optional: [Orca](https://github.com/stablyai/orca) — only for the Claude-driven path, where Grok
  runs as a supervised Orca worker with a visible terminal tab

Tested with Claude Code 2.1.273 (Claude Opus 5) and Grok Build 1.0.30 (Grok 4.6) on macOS.

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

### Grok-driven (the default)

In any git repository, open Grok Build and:

```
/team Add refresh-token rotation to the auth service
```

Grok will:
1. call Claude (headless, `docs/design/**` writable only) to write `docs/design/<date>-<slug>.md`
2. read the design and the repo, and write an adversarial review (critical / missing / ambiguous, with evidence)
3. send the review back to Claude, who checks each item against the code and revises the doc or rebuts
4. **stop and show you a summary — nothing is implemented until you say "approve"**
5. implement, run the definition-of-done tests
6. send `git diff` to Claude for review; fix until `APPROVE` (max 3 rounds)
7. report: what the review changed, files touched, tests, Claude cost

### Claude-driven

Inside an Orca worktree, in Claude Code:

```
/team Add refresh-token rotation to the auth service
```

Claude writes the design, gets Grok's adversarial review via `grok-turn.sh`, waits for your
approval, then spawns Grok as an Orca orchestration worker (`worker-start --agent grok`), answers
its questions, reviews the diff, and dispatches fixes to the same worker.

### Just a debate

```
/debate Should we move session storage from Redis to Postgres?
```

## Design quality bar

The design step is held to four rules, and the adversarial review checks each of them:
reuse before rewrite (inventory existing assets first), current as of today's date (cite the
platform's current recommendation; prefer platform primitives over hand-rolled auth/queues/cron),
measured not guessed (read-only DB/infra numbers), and no over-engineering (every component justified
against measured scale; the doc lists what was deliberately not built).

## How the safety works

The scripts don't rely on the model promising to behave:

| Mode | Permission | Effect |
|---|---|---|
| `claude-turn.sh design` | `--permission-mode dontAsk` + `Write(docs/design/**)`, `Edit(docs/design/**)`, read-only Bash | Claude can write the design doc and nothing else. Writes to source are refused by the harness |
| `claude-turn.sh review` | `dontAsk` + `Bash` allowed, `Write`/`Edit` and `git commit/checkout/reset`, `rm`, `mv`, `sed -i`… denied | Claude can run the tests but not change files |
| `grok-turn.sh` | `--permission-mode plan` | Grok is read-only |
| Approval gate | skill rule | The implementer must end its turn and wait after the design is final |

Other details that came out of real runs:
- The Claude session id is chosen **before** launch and written to `/tmp/team/last-claude-session`, so a killed or timed-out design call can be resumed with its exploration intact.
- Design prompts say "write the skeleton within 10 minutes, then fill in" and cap tool calls — Opus at high effort will otherwise explore for 20+ minutes before writing a word.
- The same Claude session is resumed for the design revision and every code review, so the reviewer remembers the design it wrote.
- `error_max_turns` → resume the same session, never start over.

## Cost and time (from a real run)

Phase 1 of a new Next.js customer app (30 files, 7 test files, 23 tests):
Claude ≈ $7 total across design + 2 review rounds (Opus 5, including one timed-out design attempt), Grok ≈ 55 min of wall time. That run predates the approval gate; with it, expect exactly one interruption. Design calls for a large scope take 20–40 minutes.

## Limitations

- Grok does **not** get Claude's project memory; only `CLAUDE.md`. That's why design and review are Claude's job.
- The review-mode Bash denylist is not exhaustive (`>` redirects, `python -c` can still write). It's a second line of defense behind the prompt, not a sandbox.
- Whether the implementer honors the approval gate is a model-compliance property, not a hard block. Grok reads the rule correctly in tests, but it has not yet been exercised in a full run — watch it on your first run.
- The Claude-driven path needs Orca. The Grok-driven path works anywhere.
- Real runs so far were on one Django + Next.js monorepo; the scripts themselves are language-agnostic.

## Layout

```
skills/
  team/SKILL.md          the workflow (paths A: Grok-driven, B: Claude-driven)
  team/claude-turn.sh    headless Claude: design | review
  debate/SKILL.md        the debate loop
  debate/grok-turn.sh    headless Grok: read-only critic
install.sh
```

## License

MIT
