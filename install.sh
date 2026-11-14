#!/usr/bin/env bash
# Installs the tandem skills into ~/.claude/ (Claude Code) and ~/.gemini/config/ (Antigravity CLI, agy).
#
#   ./install.sh               copy into both (default)
#   ./install.sh --link        symlink to this checkout so `git pull` updates in place
#   ./install.sh --claude      install only for Claude Code (plus agy's team-planner, which plans its /team)
#   ./install.sh --agy         install only for Antigravity CLI
#   ./install.sh --agy --link  combinable
#
# Existing files/folders are moved to *-backup/<name>.<timestamp> outside the active
# skills/agents directories so they are never loaded as duplicates.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="copy"
DO_CLAUDE=0
DO_AGY=0

for arg in "$@"; do
  case "$arg" in
    --link) MODE="--link" ;;
    --claude) DO_CLAUDE=1 ;;
    --agy) DO_AGY=1 ;;
    *)
      echo "Usage: $0 [--link] [--claude] [--agy]" >&2
      exit 1
      ;;
  esac
done

if [[ "$DO_CLAUDE" -eq 0 && "$DO_AGY" -eq 0 ]]; then
  DO_CLAUDE=1
  DO_AGY=1
fi
AGY_CONFIG="${AGY_CONFIG_DIR:-$HOME/.gemini/config}"

install_item() {
  local src="$1"
  local target="$2"
  local backup_dir="$3"
  local label="$4"

  mkdir -p "$(dirname "$target")"
  if [[ "$MODE" == "--link" && -L "$target" && "$(readlink "$target")" == "$src" ]]; then
    echo "already linked $label -> $target"
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "$backup_dir"
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    local backup="$backup_dir/$(basename "$target").$ts"
    if [[ -e "$backup" || -L "$backup" ]]; then
      backup="$backup.$$"
    fi
    mv "$target" "$backup"
    echo "existing $target moved to $backup"
  fi
  if [[ "$MODE" == "--link" ]]; then
    ln -s "$src" "$target"
  else
    cp -R "$src" "$target"
  fi
  echo "installed $label -> $target"
}

if [[ "$DO_CLAUDE" -eq 1 ]]; then
  CLAUDE_SKILLS="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  for skill in team debate; do
    install_item "$HERE/skills/$skill" "$CLAUDE_SKILLS/$skill" "$CLAUDE_SKILLS-backup" "claude skill $skill"
  done

  CLAUDE_AGENTS="${CLAUDE_AGENTS_DIR:-$HOME/.claude/agents}"
  install_item "$HERE/agents/team-reviewer.md" "$CLAUDE_AGENTS/team-reviewer.md" "$CLAUDE_AGENTS-backup" "claude agent team-reviewer"

  # Claude's /team has agy draft the product plan as this read-only agent.
  install_item "$HERE/agy/agents/team-planner.md" "$AGY_CONFIG/agents/team-planner.md" "$AGY_CONFIG/agents-backup" "agy agent team-planner"
fi

if [[ "$DO_AGY" -eq 1 ]]; then
  for skill in team debate ponytail ponytail-review; do
    install_item "$HERE/agy/skills/$skill" "$AGY_CONFIG/skills/$skill" "$AGY_CONFIG/skills-backup" "agy skill $skill"
  done
  chmod +x "$HERE/agy/skills/team/run-agent.sh"
  if [[ "$MODE" != "--link" && -f "$AGY_CONFIG/skills/team/run-agent.sh" ]]; then
    chmod +x "$AGY_CONFIG/skills/team/run-agent.sh"
  fi
  for agent in team-reviewer.md team-survey.md; do
    install_item "$HERE/agy/agents/$agent" "$AGY_CONFIG/agents/$agent" "$AGY_CONFIG/agents-backup" "agy agent ${agent%.md}"
  done
fi

echo
echo "Check:"
if [[ "$DO_CLAUDE" -eq 1 ]]; then
  echo "  claude:  type /team or /debate in a Claude Code session (team-reviewer shows up in a new session)"
  echo "  ponytail (required by /team): /plugin marketplace add DietrichGebert/ponytail,"
  echo "           then /plugin install ponytail@ponytail in Claude Code"
  echo "  planner: agy agents   # lists team-planner (needs agy on PATH, signed in)"
fi
if [[ "$DO_AGY" -eq 1 ]]; then
  echo "  agy:     use /team or /debate in a new Antigravity CLI session"
  echo "  vertex:  ~/.gemini/config/skills/team/run-agent.sh --preflight"
fi
