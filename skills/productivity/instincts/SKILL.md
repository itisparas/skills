---
name: instincts
description: Capture, store, and apply portable coding preferences ("instincts") as hand-editable markdown rules — a project-tier `.instincts/` folder that travels with the repo, and a user-tier `~/.instincts/` synced to `github.com/<user>/instincts`. Owns the heavy operations only — distilling instincts from a codebase, bootstrapping the user repo, pushing/pulling, promoting/demoting between tiers, and regenerating the always-on index block in AGENTS.md. The everyday apply-and-update loop runs from that index with no skill invocation. Use when a user says "learn my instincts", "remember this preference", "manage/push/pull instincts", "promote this to my user instincts", or invokes /instincts.
---

# Instincts

An **instinct** is a portable coding preference written down so an agent applies it without being re-told — like a sticky note that says *"in CLIs, reach for commander first"*. This skill owns the heavy lifting around those notes: learning them from a codebase, syncing them, and moving them between tiers. The **everyday** work — opening the right instinct before coding and nudging its confidence as you learn — runs off a lightweight index in `AGENTS.md` and needs **no** skill invocation.

It pairs with `knowledge-base`: that skill scaffolds the `.instincts/` folder and wires the index block when it sets up an org; this skill owns what goes *inside* the folder.

## Prerequisites

- A git repo. `gh` authorised (`gh auth status`) — auth is reused; falls back to `GITHUB_TOKEN`. No third-party backend.
- User tier syncs to a personal `github.com/<user>/instincts` repo (created on first `push -g`).
- `ORG_KB` optional — read it once if present, to align rule wording with the glossary.

## Running lean

- **Load once, open little.** Read only the **index block**, then open the one or two instinct files actually relevant — never the whole folder. Progressive disclosure is the whole design: the index travels in `AGENTS.md`, the rules don't.
- **ast-grep for code.** When distilling instincts from a codebase, search structurally with `ast-grep` (`sg`), not `grep` (common patterns in the `ast-grep` skill's REFERENCE.md). Keyword search is for prose only.
- **Deterministic work in `scripts/`.** Index regeneration is scripted (`scripts/index.sh`) — run it, don't hand-write the block.
- **Terse internally, plain to the user.** Scratch notes may be caveman-terse; everything the user reads stays plain and example-grounded.

## The format

One instinct = one markdown file on a single topic (`cli`, `naming`, `testing`), hand-editable. Frontmatter + one IDed rule per line with an agent-judged qualitative confidence:

```
---
name: cli
when: building a CLI
---
- [r1] use commander for TS CLIs  (0.85)
- [r2] use tsup to bundle         (0.7)
- [r3] ship a bin + npx usage      (0.6)
```

Stable `[rN]` ids power per-rule override and promote/demote; missing ids are auto-assigned on `index`.

**Two tiers** — `project` wins over `user`, merged per rule:

| | Project | User |
| --- | --- | --- |
| Lives | `<repo>/.instincts/` | `~/.instincts/` ↔ `github.com/<user>/instincts` |
| Travels with | the repo's own git (PR-reviewable) | a personal, forkable repo |
| Priority | **wins** (per-rule override) | base |

The agent **auto-classifies** project vs user when learning, without prompting; the user can hand-edit or promote anytime.

## The apply loop (always on, no invocation)

This is where instincts earn their keep, and it lives in `AGENTS.md`, not here:

- An **index block** (`name | when | path | tier`) sits in `AGENTS.md`, mirrored to `CLAUDE.md` — the lightweight index only, never the full rules.
- Before coding, the agent opens just the relevant instinct, applies it by **soft weighting** — **≥0.8 follow · 0.5–0.8 prefer · <0.5 hint** — and updates rules and confidence **in place** as it learns.

## Operations (heavy ops only)

The agent does all distillation; transport is plain git + `gh`. Trigger on `/instincts` or intent.

- **Learn / distill** — read the codebase (ast-grep) and the user's stated preferences, write or revise instinct files, auto-classify each into project or user tier.
- **Bootstrap user repo** — create `github.com/<user>/instincts` and seed `~/.instincts/` on first `push -g`.
- **push / pull** — default = **project** tier: a scoped commit of `./.instincts/**` only, on the current branch, **no auto-push** — it rides the user's next PR. `-g` = **user** tier, synced to the personal repo. `pull alice/testing` cross-imports another user's public instinct as plain files you own.
- **promote / demote** — move a rule between tiers (confirm with the user before promoting project → user).
- **index** — regenerate the `AGENTS.md`/`CLAUDE.md` block: `scripts/index.sh [repo-root]`.
- **manage** — `list · new · open · rm · diff · history · show` (effective merged view).

## Gates & marker

- **No auto-push, no surprise promotion.** Project changes ride the next PR; promoting a rule to the user tier (which leaks it across every repo) needs an explicit human yes.
- **No comment marker.** This skill commits files; it posts no GitHub issue/PR comments, so it claims no marker in the README registry. Its artefacts are the `.instincts/` files themselves.
