# Editing this repo

- Every skill and agent file under `skills/` and `agents/` has an Antigravity CLI (agy) port under
  `agy/`, and `README.md` has `README.ko.md`. A change to one goes to its pair in the same commit, or
  the commit message says `no-port: <why>`. `agy/agents/team-planner.md` has no Claude pair: it is
  the agy agent that Claude's /team starts for the product plan.
- agy's agents (`team-reviewer`, `team-planner`) have no tool that writes files or runs commands
  (file reads, web search): a change that needs git or grep output gives it to them as files.
- After a context compaction Claude Code re-attaches only about the first 5,000 tokens of a skill (the
  team skill measured ≈2.5 bytes per token). Keep the re-read paragraph and the safety rules
  (approval, test data, messages and payments, review) in the first 11 KB of `skills/team/SKILL.md`
  (`head -c 11000`), and the re-read line in `agy/skills/team/SKILL.md`'s `description`; what falls past 11 KB comes back
  only through the re-read.
- A change that makes `skills/team/` bigger says in the PR body how many bytes it adds and what it
  removed.
- The repo is public: no service names, customer data or one project's rules in the skills.
