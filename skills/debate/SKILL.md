---
name: debate
description: >-
  Claude <-> Grok cross-model debate loop. Claude drafts (a design, plan or implementation), calls
  Grok Build headlessly (read-only) for criticism and alternatives, rebuts or accepts each point with
  evidence, repeats, then reports the consensus to the user. Use immediately when the user says
  "/debate", "discuss with grok", "have the AIs debate", "second model opinion", "cross-review",
  "discuss and get a better result". Also use unprompted for: non-trivial design/architecture
  decisions, changes affecting payments/DB/customers, contested trade-offs, and a final review after
  an implementation. Not for simple questions, typo fixes, or obvious one-line changes.
argument-hint: "[topic — empty means the work currently in progress]"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# /debate — Claude ↔ Grok cross-model debate

Purpose: two models argue the same proposal on evidence, back and forth, to produce something better
than either alone. The user sets nothing up and only receives the result.

## Roles

| | Claude (me) | Grok |
|---|---|---|
| Rights | edit, run, final synthesis | **read-only** (plan mode, cannot modify files) |
| Role | driver: drafts, verifies, rebuts/accepts, applies consensus | critical co-designer: reads the repo directly and objects, proposes, asks — with evidence |

## Tool

```bash
bash ~/.claude/skills/debate/grok-turn.sh <prompt-file> [session-id|new] [max-turns]
# → {"sessionId":"…","text":"…","cost":0.01,"stopReason":"end_turn"}
```

- First round `new`; later rounds pass the returned `sessionId` (Grok remembers the conversation,
  so never repeat earlier content).
- Always pass prompts as files (`/tmp/team/<slug>/debate-r<N>.md`) to avoid shell quoting.
- `max-turns` default 8: how many file reads/greps Grok may do. Use 12–15 for large code reviews,
  30 for a design review.
- If the result has `"maxTurns": true`, resume **the same `sessionId`** with "Stop exploring. Answer
  now in the required format from what you have." (max-turns 10). Never start a new session for it.
- A new session's id is written to stderr and `<prompt dir>/last-grok-session` before Grok starts,
  so a killed call can be resumed.
- The script `cd`s to the repository root itself.
- About $0.01–0.05 per turn.

## Procedure

### 0. Frame the question + draft
Write the user's request as a one-paragraph **proposal**. For code work, Claude drafts first (a
decision list for a design, the actual diff for an implementation). Never just ask "what do you
think?" without a draft — the debate converges only when there is something to attack.

### 1. Round 1 prompt (`debate-r1.md`)
```
You are a senior engineer and critical co-designer for this repository. Repository path: <cwd>
Proposal: <proposal>
My draft:
<draft / diff / decision list>
Relevant files: <paths — so Grok reads them itself and cites evidence>

Requirements:
- Actually read the files and cite evidence (file:line). Mark guesses as guesses.
- Use this format:
  ## Agree
  ## Disagree (evidence for each item)
  ## Alternatives (concrete, and why better)
  ## Questions (information needed to judge)
  ## Verdict: agree | conditional agree (state conditions) | disagree
- Also judge: is anything here a rewrite of an asset that already exists? a hand-rolled version of
  something the platform provides as of today? over-engineered for the measured scale? unmeasured?
- Don't be polite; if something is wrong, say so. Answer in the user's language.
```

### 2. Examine Grok's response (the core — never accept on authority)
For each objection/alternative, **check the code/docs directly** and judge:
- Correct → accept, revise the draft
- Wrong → rebut with evidence (file:line, test result, observed behavior)
- Needs checking → actually check (grep, run tests) before judging
Answer Grok's questions. If you don't know, say so.

### 3. Round N prompt (resume the same session)
Only new information and open points, briefly:
```
Accepted: <item> → draft changed like this: <change>
Rebutted: <item> — evidence: <file:line / result>
Answers: <answers to Grok's questions>
Please also check: <specific spots Grok should look at>
Answer in the same format and update your verdict.
```

### 4. Stop conditions (whichever comes first)
- Grok's verdict is **agree** with no new objections
- Max rounds reached — default **3** ("go deep" → 5, "keep it light" → 2)
- The remaining disagreement is a **business judgment** the code can't settle (cost, customer
  impact, operating policy) → stop and hand it to the user

### 5. Apply consensus + final review
Apply the consensus to the design/code. For implementation work, attach `git diff` afterwards and
run **one final review round** ("check only whether this diff reflects the consensus exactly, and
regression risk").

### 6. Report to the user (once)
```
## Consensus
- key decisions as bullets

## What the debate changed  ← this is the value: what improved vs the draft
- draft: … → consensus: … (Grok's point: …, evidence: …)

## Unresolved (only if any)
- issue / Claude's position + evidence / Grok's position + evidence / why the user must decide

N rounds, Grok cost $X
```
Keep the full transcript per round in `/tmp/team/<slug>/debate-log.md` (show it if the user asks
"show me the debate").

## Rules
- Don't interrupt the user mid-debate. Report once at the end. Exception: the business-judgment
  case in step 4.
- Grok's claims are accepted only after verification. Claude's claims aren't pushed without
  evidence either.
- Only Claude edits and runs things. Never tell Grok to "fix it".
- No verification that writes to production databases or external services (reads only).
- Keep round prompts short; the session remembers.
- If `grok-turn.sh` returns `error` (other than `maxTurns`, handled above), retry once; if it keeps
  failing, continue without Grok and say so in the report.
