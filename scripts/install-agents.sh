#!/usr/bin/env bash
# Install the reusable pipeline agents into a harness's agents directory.
#
# `npx skills` installs SKILL.md folders only — it does NOT install agents
# (.claude/agents/*.md). Run this to symlink the agents in agents/ so skills
# can spawn them by name (kb-investigator, standards-reviewer, spec-reviewer)
# and pick up their model/tools frontmatter.
#
# Usage:
#   scripts/install-agents.sh           # per-project  -> .claude/agents/
#   scripts/install-agents.sh -g        # global       -> ~/.claude/agents/
#   scripts/install-agents.sh --copy    # copy instead of symlink
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/agents"

DEST=".claude/agents"
MODE="link"
for arg in "$@"; do
  case "$arg" in
    -g|--global) DEST="$HOME/.claude/agents" ;;
    --copy)      MODE="copy" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$DEST"
for f in "$SRC"/*.md; do
  name="$(basename "$f")"
  target="$DEST/$name"
  rm -f "$target"
  if [ "$MODE" = "copy" ]; then
    cp "$f" "$target"
  else
    ln -s "$f" "$target"
  fi
  echo "installed $name -> $DEST"
done

echo "Done. Agents available: kb-investigator, standards-reviewer, spec-reviewer."
