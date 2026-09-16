#!/usr/bin/env bash
# Installs the tandem skills into ~/.claude/skills/ (read by both Claude Code and Grok Build).
#
#   ./install.sh          copy  (default)
#   ./install.sh --link   symlink to this checkout so `git pull` updates the skills in place
#
# An existing ~/.claude/skills/team or /debate is moved to ~/.claude/skills-backup/<name>.<timestamp>, never deleted.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MODE="${1:-copy}"

mkdir -p "$DEST"
for skill in team debate; do
  target="$DEST/$skill"
  if [[ -e "$target" || -L "$target" ]]; then
    # Move aside OUTSIDE the skills dir — anything left inside would be loaded as a duplicate skill.
    mkdir -p "$DEST-backup"
    backup="$DEST-backup/$skill.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    echo "existing $target moved to $backup"
  fi
  if [[ "$MODE" == "--link" ]]; then
    ln -s "$HERE/skills/$skill" "$target"
  else
    cp -R "$HERE/skills/$skill" "$target"
  fi
  chmod +x "$target"/*.sh
  echo "installed $skill -> $target"
done

echo
echo "Check:"
echo "  claude:  type /team or /debate in a Claude Code session"
echo "  grok:    grok inspect   # should list 'team' and 'debate' under Skills"
