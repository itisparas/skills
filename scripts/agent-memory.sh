#!/usr/bin/env bash
# agent-memory.sh — deterministic helper for the pipeline's non-authoritative memory cache.
#
# Memory is a THROWAWAY ACCELERATOR, never a source of truth. GitHub (issues / PRDs / PR
# comments / labels) remains authoritative; `.agent-memory/` only makes the next turn cheaper.
# A cache miss is always safe — the caller re-derives cold (today's behaviour). So this script
# never fails hard on a miss; it prints nothing and exits 0 so callers can branch on empty output.
#
# Store layout (gitignored — see .gitignore):
#   .agent-memory/
#     issue-<n>.md   kb-investigator's codebase map for a brief→PRD→task chain
#     pr-<n>.md      reviewers' digest + finding ledger for a PR
#     INDEX.md       one-line pointer per memory file (cheap to scan on entry)
#
# Every memory file opens with frontmatter carrying `stamp:` — the commit SHA the facts were
# derived against — mirroring the user-memory convention (name/description/metadata + INDEX).
#
# Subcommands:
#   read <key>              print the memory file for <key> (e.g. issue-250, pr-251), or nothing on miss
#   stamp <key>             print the `stamp:` SHA recorded in that file, or nothing
#   stale-paths <key>       list files changed since the stamped SHA (which cached facts to re-derive)
#   write <key> <stamp>     read a memory body on stdin, write it with a fresh stamp + INDEX pointer
#   path <key>              print the absolute path for <key> (callers that prefer the Write tool)
#
# Usage from an agent: `read` first, `stale-paths` to scope the delta, do only that work, then `write`.

set -euo pipefail

repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }
MEM_DIR="$(repo_root)/.agent-memory"
file_for() { printf '%s/%s.md' "$MEM_DIR" "$1"; }

cmd="${1:-}"; key="${2:-}"

case "$cmd" in
  path)
    [ -n "$key" ] || { echo "usage: agent-memory.sh path <key>" >&2; exit 2; }
    file_for "$key"
    ;;

  read)
    [ -n "$key" ] || { echo "usage: agent-memory.sh read <key>" >&2; exit 2; }
    f="$(file_for "$key")"
    [ -f "$f" ] && cat "$f" || true   # miss → empty, exit 0 (caller re-derives cold)
    ;;

  stamp)
    [ -n "$key" ] || { echo "usage: agent-memory.sh stamp <key>" >&2; exit 2; }
    f="$(file_for "$key")"
    [ -f "$f" ] && sed -n 's/^stamp:[[:space:]]*//p' "$f" | head -n1 || true
    ;;

  stale-paths)
    # Files changed since the stamped SHA → exactly the cached facts that may be stale.
    # No stamp / unknown SHA → print nothing and exit 0; caller treats it as a full miss.
    [ -n "$key" ] || { echo "usage: agent-memory.sh stale-paths <key>" >&2; exit 2; }
    f="$(file_for "$key")"
    [ -f "$f" ] || exit 0
    sha="$(sed -n 's/^stamp:[[:space:]]*//p' "$f" | head -n1)"
    [ -n "$sha" ] || exit 0
    git rev-parse --verify --quiet "$sha^{commit}" >/dev/null 2>&1 || exit 0
    git diff --name-only "$sha"..HEAD || true
    ;;

  write)
    # Body on stdin. Front-matter `stamp:` is rewritten/inserted to the given SHA.
    stamp="${3:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
    [ -n "$key" ] || { echo "usage: agent-memory.sh write <key> [stamp]  (body on stdin)" >&2; exit 2; }
    mkdir -p "$MEM_DIR"
    f="$(file_for "$key")"
    body="$(cat)"
    # Drop any stamp the caller embedded, then prepend the canonical one.
    printf 'stamp: %s\n%s\n' "$stamp" "$(printf '%s\n' "$body" | grep -v '^stamp:' || true)" > "$f"
    # Maintain the INDEX pointer (one line per key), dedup on the key prefix.
    idx="$MEM_DIR/INDEX.md"
    touch "$idx"
    grep -v "^- ${key} " "$idx" 2>/dev/null > "$idx.tmp" || true
    printf -- '- %s @ %s\n' "$key" "$stamp" >> "$idx.tmp"
    mv "$idx.tmp" "$idx"
    echo "$f"
    ;;

  *)
    cat >&2 <<'EOF'
agent-memory.sh — non-authoritative pipeline memory cache (safe to delete anytime)
  read <key>            print memory for <key> (issue-<n> / pr-<n>), empty on miss
  stamp <key>           print the recorded commit SHA
  stale-paths <key>     files changed since that SHA — the cached facts to re-derive
  write <key> [stamp]   write a memory body from stdin with a fresh stamp + INDEX pointer
  path <key>            print the file path for <key>
EOF
    exit 2
    ;;
esac
