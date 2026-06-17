#!/usr/bin/env bash
# Scaffold a local numbered-folder knowledge-base vault. Idempotent — never overwrites
# an existing file. Usage: scaffold-local.sh <ORG_KB-root>
set -euo pipefail

ROOT="${1:?usage: scaffold-local.sh <ORG_KB-root>}"
mkdir -p "$ROOT"

# folder | one-line purpose (becomes the index.md heading)
folders=(
  "00-meta|How the vault works: conventions, templates, changelog"
  "01-overview|Vision, goals, glossary"
  "02-architecture|How systems are designed and built"
  "03-research|Real research: dated, concluded investigations"
  "04-prds|Requirements — what must be built and why"
  "05-plans|Roadmaps, plans, work queues"
  "06-status|What is true right now: now, decisions, logs, incidents"
  "07-reference|Stable lookup: spec, schemas, examples"
  "08-briefs|Scoped, self-contained work briefs"
  "09-company|Brand, philosophy, voice"
  "10-issues|Grabbable implementation issues"
  "11-adrs|Architecture Decision Records — full records"
  "12-memories|Standing instincts: the append-only memory log"
  "archive|Superseded docs — never deleted"
)

write_once() { [ -f "$1" ] && echo "exists   $1" || { printf '%s' "$2" >"$1"; echo "created  $1"; }; }

for entry in "${folders[@]}"; do
  IFS='|' read -r dir purpose <<<"$entry"
  mkdir -p "$ROOT/$dir"
  write_once "$ROOT/$dir/index.md" "$(printf -- '---\ntitle: %s\nstatus: active\ntags: [index]\n---\n\n# %s\n\n%s\n' "$dir" "$dir" "$purpose")"
done

# status sub-folders for the artifacts that move draft -> active -> complete
for d in 04-prds 08-briefs 10-issues; do mkdir -p "$ROOT/$d"/{draft,active,complete}; done

# top-level entry points
write_once "$ROOT/INDEX.md" "$(printf -- '---\ntitle: Knowledge Base — Master Index\nstatus: active\ntags: [index]\n---\n\n# Knowledge Base — Master Index\n\nStart here. Each numbered folder holds one kind of knowledge; every folder has an index.md.\nStructural contract: 00-meta/conventions.md.\n')"
write_once "$ROOT/CLAUDE.md" "@AGENTS.md"

echo "Vault scaffolded at $ROOT. Next: write 00-meta/conventions.md (the structural contract) and the AGENTS.md pointer block."
