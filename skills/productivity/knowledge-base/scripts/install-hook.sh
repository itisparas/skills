#!/usr/bin/env bash
# Install the detect-and-offer SessionStart hook into .claude/settings.json.
# It only prints a suggestion when no kb-config.yml is present — it never launches
# the wizard. Idempotent. Usage: install-hook.sh [settings-path]
set -euo pipefail

SETTINGS="${1:-.claude/settings.json}"
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' >"$SETTINGS"

CMD="test -f kb-config.yml || printf 'No knowledge base found here. Run /knowledge-base to set one up.\\n'"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found. Add this SessionStart hook to $SETTINGS by hand:"
  echo "  command: $CMD"
  exit 0
fi

tmp="$(mktemp)"
jq --arg cmd "$CMD" '
  .hooks.SessionStart = (.hooks.SessionStart // [])
  | if any(.hooks.SessionStart[]?; .hooks[]?.command == $cmd)
    then .
    else .hooks.SessionStart += [ { "hooks": [ { "type": "command", "command": $cmd } ] } ]
    end
' "$SETTINGS" >"$tmp" 2>/dev/null && mv "$tmp" "$SETTINGS" \
  && echo "Hook installed in $SETTINGS" \
  || { rm -f "$tmp"; echo "Could not edit $SETTINGS automatically — add the SessionStart hook by hand (command: $CMD)."; }
