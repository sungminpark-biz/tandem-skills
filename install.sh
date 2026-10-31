#!/usr/bin/env bash
# Installs the tandem skills into ~/.claude/ (Claude Code) and ~/.gemini/ (Gemini CLI).
#
#   ./install.sh                  copy into both ~/.claude and ~/.gemini (default)
#   ./install.sh --link           symlink to this checkout so `git pull` updates in place
#   ./install.sh --claude         install only for Claude Code
#   ./install.sh --gemini         install only for Gemini CLI
#   ./install.sh --gemini --link  combinable
#
# Existing files/folders are moved to *-backup/<name>.<timestamp> outside the active
# skills/agents/policies directories so they are never loaded as duplicates.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="copy"
DO_CLAUDE=0
DO_GEMINI=0

for arg in "$@"; do
  case "$arg" in
    --link) MODE="--link" ;;
    --claude) DO_CLAUDE=1 ;;
    --gemini) DO_GEMINI=1 ;;
    *)
      echo "Usage: $0 [--link] [--claude] [--gemini]" >&2
      exit 1
      ;;
  esac
done

if [[ "$DO_CLAUDE" -eq 0 && "$DO_GEMINI" -eq 0 ]]; then
  DO_CLAUDE=1
  DO_GEMINI=1
fi

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
fi

if [[ "$DO_GEMINI" -eq 1 ]]; then
  GEMINI_HOME="${GEMINI_HOME_DIR:-$HOME/.gemini}"
  GEMINI_SKILLS="${GEMINI_SKILLS_DIR:-$GEMINI_HOME/skills}"
  for skill in team debate ponytail ponytail-review; do
    install_item "$HERE/gemini/skills/$skill" "$GEMINI_SKILLS/$skill" "$GEMINI_SKILLS-backup" "gemini skill $skill"
  done

  GEMINI_AGENTS="${GEMINI_AGENTS_DIR:-$GEMINI_HOME/agents}"
  install_item "$HERE/gemini/agents/team-reviewer.md" "$GEMINI_AGENTS/team-reviewer.md" "$GEMINI_AGENTS-backup" "gemini agent team-reviewer"

  GEMINI_POLICIES="${GEMINI_POLICIES_DIR:-$GEMINI_HOME/policies}"
  install_item "$HERE/gemini/policies/team-reviewer.toml" "$GEMINI_POLICIES/team-reviewer.toml" "$GEMINI_POLICIES-backup" "gemini policy team-reviewer.toml"

  install_item "$HERE/gemini/team-reviewer-probe.mjs" "$GEMINI_HOME/team-reviewer-probe.mjs" "$GEMINI_HOME/policies-backup" "gemini probe team-reviewer-probe.mjs"
fi

echo
echo "Check:"
if [[ "$DO_CLAUDE" -eq 1 ]]; then
  echo "  claude:  type /team or /debate in a Claude Code session (team-reviewer shows up in a new session)"
  echo "  ponytail (required by /team): /plugin marketplace add DietrichGebert/ponytail,"
  echo "           then /plugin install ponytail@ponytail in Claude Code"
fi
if [[ "$DO_GEMINI" -eq 1 ]]; then
  echo "  gemini:  use /team or /debate in a Gemini CLI / Orca IDE session (restart session to reload)"
  echo "  policy:  node ~/.gemini/team-reviewer-probe.mjs"
fi
