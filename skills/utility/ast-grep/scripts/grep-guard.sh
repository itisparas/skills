#!/usr/bin/env bash
# PreToolUse(Bash) guard: nudge code search from `grep` toward `ast-grep` (sg).
#
# Reads the hook JSON on stdin, looks at the Bash command, and emits a
# non-blocking reminder when `grep`/`rg` is run against code. It never blocks:
# grep over prose, logs, and plain text is legitimate, so this only advises.
#
# Wire it via scripts/install-grep-hook.sh (PreToolUse, matcher "Bash").
set -euo pipefail

input="$(cat)"

# Pull the command string out of the hook payload (jq if present, else a
# best-effort grep fallback so the hook still works without jq installed).
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
else
  cmd="$(printf '%s' "$input" | tr -d '\n' | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')"
fi

# Only fire when the command actually invokes grep/rg as a command (not as a
# substring of another word like `ripgrep-config` or `grepney`).
if printf '%s' "$cmd" | grep -Eq '(^|[|&;[:space:]])(grep|rg)([[:space:]]|$)'; then
  # If a code-ish file/extension or a recursive code search is present, advise.
  if printf '%s' "$cmd" | grep -Eq '\.(ts|tsx|js|jsx|py|go|rs|rb|java|kt|c|h|cpp|cc|swift|php|cs)\b|(-r|-R|--recursive|--include)'; then
    echo "Reminder: use \`ast-grep\` (\`sg\`) for code search, not grep — it matches by AST, not text. See the ast-grep skill's REFERENCE.md. (grep stays fine for prose/logs.)" >&2
  fi
fi

# Always exit 0 — advisory only, never blocks the tool call.
exit 0
