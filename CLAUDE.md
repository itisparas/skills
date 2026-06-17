# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of **agent skills** for an **idea-to-merge workflow** built around an organisation knowledge base (`ORG_KB`), GitHub issues/PRs, and Notion. Each skill is a self-contained `SKILL.md` (plus optional bundled refs/scripts) that an agent loads on demand. There is no application code, build step, or test harness — the deliverable is the prose in each `SKILL.md`.

These skills target **private orgs / small projects**, not large public repos. Keep that audience in mind: lean on human gates and direct interviews rather than community-scale batch machinery.

## Layout

Skills live under a **category directory**: `skills/<category>/<name>/SKILL.md`.

- `skills/engineering/` — the idea-to-merge build pipeline (`ideate`, `create-prd`, `review-pr`)
- `skills/utility/` — standalone tools (`ast-grep`)
- `skills/productivity/` — routines that speed a human/agent (`write-a-skill`)
- `skills/communication/`, `skills/domain/` — reserved for style-mode and domain-knowledge skills (see `write-a-skill` Step 3 for the placement → directory map)

**Authoring context matters.** The category layout above is for *this* repo. When `write-a-skill` runs inside a **live target project** (skills installed there via `npx skills`), it instead writes the skill flat under that runner's convention (`.agents/skills/<name>/` or the harness skills dir) and symlinks into harness-specific locations — not the category layout.

When you move or rename a skill, update the README **Skills** table links and the manual-install symlink paths. Skills reference each other by **name** (e.g. "see the `ast-grep` skill"), never by path, so moves don't break cross-references.

## The control plane: labels + markers

This is the load-bearing architectural idea — read the README's **Labels**, **Comment markers**, and **Conventions** sections; they are the single source of truth.

- Every branch, route, and human hand-off is decided by a **GitHub label** — never inferred from prose. A skill picks up work because an issue carries a label, advances by swapping labels, and asks for a human by applying one.
- **Human gates are human-only labels** (`state:prd-ready`, `state:agent-ready`) that agents read but **never** apply. This is non-negotiable; it's what keeps the pipeline auditable.
- Every agent comment opens with a distinct **marker** line (`> **⚓️ ideate-agent**`, etc.). No two skills share a marker; the README table is the registry.

Pipeline: raw idea → `ideate` (lean `type:brief`) → human applies `state:prd-ready` → `create-prd` (durable `type:prd`) → human applies `state:agent-ready` → `build-from-issue` (sibling, **not** in this repo) → PR → `review-pr`.

## The house contract (how every SKILL.md is written)

`skills/productivity/write-a-skill/SKILL.md` is the authoritative spec and the smith that enforces it. When adding or editing any skill, satisfy its contract. The essentials:

- **Description with triggers** — third person, ≤1024 chars, first sentence = what it does, then "Use when …" with concrete trigger phrases.
- **`Running lean` section** — load `ORG_KB` once, search narrow (`ast-grep`/`sg` for code, keyword search only for prose), progressive disclosure, sub-agents for big reads, stable prompt prefix for cache warmth.
- **Dual register** — internal scratch reasoning may be caveman-terse; everything the *user* reads stays plain, warm, and complete. Never let terseness leak into user-facing text.
- **Non-technical by default** — plain words, a quick analogy for anything technical, questions grounded in a live worked example.
- **Org-aware** — reads `ORG_KB`, respects the glossary (`CONTEXT.md` / `CONTEXT-MAP.md`) and ADRs (`docs/adr/` or Notion), doesn't duplicate an existing skill, carries a distinct marker if it posts comments.
- **Progressive disclosure** — `SKILL.md` stays **≤ ~150 lines**; push long reference/examples into `REFERENCE.md`/`EXAMPLES.md` one level deep; deterministic work into `scripts/`.
- **No time-sensitive info** — convert relative dates to absolute; one name per concept.

## Verifying a skill before commit

There is no code test harness. Verification is:

1. Walk **`write-a-skill` Step 7's contract checklist** — it is the acceptance test.
2. `wc -l SKILL.md` to confirm ≤ ~150 lines (else split into refs).
3. `npx skills add itisparas/skills --list` to confirm the skill is discoverable and frontmatter parses.
4. Confirm any new marker/label is registered in the README tables (markers must be unique).

A lint script (frontmatter + line-count + marker/label uniqueness) under `scripts/` would be a worthwhile future addition; none exists yet.

## Tooling

- **`ast-grep`** (`sg`) — all code search, in place of `grep`. `brew install ast-grep`. See `skills/utility/ast-grep/SKILL.md`.
- **`gh`** CLI, authenticated — issues, labels, PR comments.
- **Notion MCP** — configured per the prerequisites block in each skill.
- **`ORG_KB`** env var — points at the org knowledge base; loaded once per run.

## Commits

Use the user's identity only — never add a Claude/Anthropic co-author trailer.
