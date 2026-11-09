# Editing this repo

- Every skill and agent file under `skills/` and `agents/` has a Gemini CLI port under `gemini/`
  (`skills/team/plan-policy.toml` has none: Gemini plans in its own session), and `README.md` has
  `README.ko.md`. A change to one goes to its pair in the same commit, or the commit message says
  `no-port: <why>`.
- After a context compaction Claude Code re-attaches only about the first 5,000 tokens of a skill (the
  team skill measured ≈2.5 bytes per token), and Gemini CLI keeps none of it, only its `description`.
  Keep rules that must hold for a whole run, and the re-read paragraph, in the first 11 KB of
  `skills/team/SKILL.md` (`head -c 11000`), and the Gemini re-activate line in its `description`.
- A change that makes `skills/team/` bigger says in the PR body how many bytes it adds and what it
  removed.
- The repo is public: no service names, customer data or one project's rules in the skills.
