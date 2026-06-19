#!/usr/bin/env bash
# Install the grep-guard as a Claude Code PreToolUse hook on Bash.
#
# Adds a hooks.PreToolUse entry (matcher "Bash") that runs grep-guard.sh, which
# advises switching code-search greps to `ast-grep` (sg). It is advisory only —
# the hook never blocks a command.
#
# Usage:
#   scripts/install-grep-hook.sh        # writes to .claude/settings.json
#   scripts/install-grep-hook.sh -g     # writes to ~/.claude/settings.json
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$DIR/grep-guard.sh"
chmod +x "$GUARD"

SETTINGS=".claude/settings.json"
[ "${1:-}" = "-g" ] && SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to merge the hook into $SETTINGS. Add this PreToolUse hook manually:" >&2
  echo "  matcher \"Bash\" -> command: $GUARD" >&2
  exit 1
fi

tmp="$(mktemp)"
jq --arg cmd "$GUARD" '
  .hooks //= {} |
  .hooks.PreToolUse //= [] |
  .hooks.PreToolUse += [{
    "matcher": "Bash",
    "hooks": [{ "type": "command", "command": $cmd }]
  }]
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "Installed grep-guard PreToolUse(Bash) hook into $SETTINGS"
