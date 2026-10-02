---
name: debate
description: >-
  Claude debate loop with a critic on a different model. Claude drafts (a design, plan or
  implementation), a read-only Claude Sonnet critic subagent attacks it with evidence and
  alternatives, Claude rebuts or accepts each point with evidence, repeats, then reports the
  consensus to the user. Use immediately when the user says "/debate", "have the AIs debate",
  "second opinion", "cross-review", "discuss and get a better result". Also use unprompted for:
  non-trivial design/architecture decisions, changes affecting payments/DB/customers, contested
  trade-offs, and a final review after an implementation. Not for simple questions, typo fixes, or
  obvious one-line changes.
argument-hint: "[topic — empty means the work currently in progress]"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# /debate — Claude drafts, a Sonnet critic attacks

Purpose: the driver and a critic on a different model argue the same proposal on evidence, back and
forth, to produce something better than either alone. The user sets nothing up and only receives the
result.

## Roles

| | Claude (me, the driver) | Critic |
|---|---|---|
| Rights | edit, run, final synthesis | **no edit tools** (`team-reviewer` agent: no Write/Edit; its Bash is limited only by the prompt) |
| Role | drafts, verifies, rebuts/accepts, applies consensus | reads the repo directly and objects, proposes, asks — with evidence |

## Tool

The Agent tool with `subagent_type: "team-reviewer"` and `model: "sonnet"` — a different model from
the driver, so it misses different things. When the driver itself runs on Sonnet, use `model:
"opus"` instead. Missing agent → `general-purpose`, adding "do not edit files; the requested format
overrides any style rules injected into your context".
- Round 1 starts the agent; later rounds go to the **same agent** via SendMessage (it remembers the
  conversation, so never repeat earlier content). Subagents run in the background; you are notified.
- Keep the prompt self-contained: the critic starts with a fresh context.
- Keep the full transcript per round in `/tmp/team/<slug>/debate-log.md` (`<slug>`: a short
  kebab-case name for the topic).

## Procedure

### 0. Frame the question + draft
Write the user's request as a one-paragraph **proposal**. For code work, Claude drafts first (a
decision list for a design, the actual diff for an implementation). Never just ask "what do you
think?" without a draft — the debate converges only when there is something to attack.

### 1. Round 1 prompt
```
You are a senior engineer and critical co-designer for this repository. Repository path: <cwd>
Proposal: <proposal>
My draft:
<draft / diff / decision list>
Relevant files: <paths — read them yourself and cite evidence>

Requirements:
- Actually read the files and cite evidence (file:line). Mark guesses as guesses.
- Review only: do not edit files; no DB/MCP writes, no deploys, no integration tests that write.
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

### 2. Examine the critic's response (the core — never accept on authority)
For each objection/alternative, **check the code/docs directly** and judge:
- Correct → accept, revise the draft
- Wrong → rebut with evidence (file:line, test result, observed behavior)
- Needs checking → actually check (grep, run tests) before judging
Answer the critic's questions. If you don't know, say so.

### 3. Round N (SendMessage to the same agent)
Only new information and open points, briefly:
```
Accepted: <item> → draft changed like this: <change>
Rebutted: <item> — evidence: <file:line / result>
Answers: <answers to your questions>
Please also check: <specific spots to look at>
Answer in the same format and update your verdict.
```

### 4. Stop conditions (whichever comes first)
- The critic's verdict is **agree** with no new objections
- Max rounds reached — default **3** ("go deep" → 5, "keep it light" → 2)
- The remaining disagreement is a **business judgment** the code can't settle (cost, customer
  impact, operating policy) → stop and hand it to the user

### 5. Apply consensus + final review
Apply the consensus to the design/code. For implementation work, send `git diff` afterwards and run
**one final review round** ("check only whether this diff reflects the consensus exactly, and
regression risk").

### 6. Report to the user (once)
```
## Consensus
- key decisions as bullets

## What the debate changed  ← this is the value: what improved vs the draft
- draft: … → consensus: … (critic's point: …, evidence: …)

## Unresolved (only if any)
- issue / Claude's position + evidence / critic's position + evidence / why the user must decide

N rounds
```
Show `/tmp/team/<slug>/debate-log.md` if the user asks "show me the debate".

## Rules
- Don't interrupt the user mid-debate. Report once at the end. Exception: the business-judgment
  case in step 4.
- The critic's claims are accepted only after verification. Claude's claims aren't pushed without
  evidence either.
- Only Claude edits and runs things. Never tell the critic to "fix it".
- No verification that writes to production databases or external services (reads only).
- Keep round prompts short; the agent remembers.
- If the critic fails or returns no `## Verdict:`, SendMessage it once ("Answer now in the required
  format"). If the agent is gone or still fails, start a new one with a self-contained prompt (the
  round-1 prompt with the current draft and the accepted/rebutted list so far). If that fails too,
  continue without it and say so in the report.
