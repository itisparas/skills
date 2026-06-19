---
name: knowledge-base
description: Bootstrap and own an organisation's knowledge base — interview the user to choose a backend (GitHub, Notion, local folders, or a hybrid), record the choice, scaffold the full idea-to-merge structure (pipeline labels, databases, or numbered folders, plus AGENTS.md), and stay on as caretaker of that structure. Use when a project has no knowledge base yet, when ORG_KB is unset or missing, when a SessionStart hook reports no KB config, or when a user says "set up a knowledge base", "bootstrap our docs", "we have no ORG_KB", "create our org wiki", "where do our decisions live", or invokes /knowledge-base.
---

# Knowledge Base

The front door to *creating* the substrate every other skill assumes. `ideate`, `create-prd`, `slice-prd`, and `review-pr` all read an existing `ORG_KB`; this skill is the one that builds it. It interviews the user, sets up the backend they pick, wires the agent files so the whole skill family knows where things live, and then stays on as **caretaker of the structure** — adding folders/labels, repairing drift, migrating backends. It does **not** write the notes themselves; that stays with `ideate` and friends.

## Prerequisites

- `ORG_KB` — the org knowledge base. It may **not exist yet** — that's the point. After setup, `ORG_KB` points at the new KB root.
- `gh` CLI authorised (`gh auth status`) — needed for the GitHub and hybrid backends.
- Notion MCP installed — needed for the Notion and hybrid backends. If a call fails, set it up and retry:

```bash
# Claude Code
claude mcp add --transport http notion https://mcp.notion.com/mcp   # then run /mcp and follow OAuth
# Codex CLI
codex mcp add notion --url https://mcp.notion.com/mcp && codex --enable rmcp_client && codex mcp login notion
```

## Running lean

- **Load once.** Read any existing `kb-config.yml` and `AGENTS.md` once in Step 1; work from a short in-memory summary.
- **Search narrow.** Detection is a handful of file/label checks, not a repo crawl. For **code** use `ast-grep` (`sg`), never `grep` (common patterns in the `ast-grep` skill's REFERENCE.md); keyword search is only for **prose**.
- **Deterministic work lives in `scripts/`.** Folder creation, label creation, and hook install are scripted — run them, don't regenerate the steps as prose. Long per-backend detail lives in [REFERENCE.md](REFERENCE.md), read only for the backend the user picked.
- **Terse internally, plain to the user.** Scratch notes can be caveman-terse (`bk -> gh+notion`); everything the user reads stays warm, plain, and example-grounded (Step 2).

## Where this fits the control plane

This skill sits **before** the label pipeline — it is what *creates* the control-plane labels (`type:brief`, `state:prd-ready`, …) the other skills route on, so it picks up no work by label and mints no new ones. Its one human gate is **confirmation before writing**: on an existing KB it only ever *adds or repairs*, and any destructive step (overwrite, backend migration that drops data) needs an explicit human yes — it never auto-destroys. It posts/edits with the marker `> **🧭 knowledge-base-agent**`.

## Step 1: Detect — fresh ground or existing KB?

Look for `kb-config.yml` at the KB root (the vault root for local; the repo root holding `AGENTS.md` for GitHub/Notion). Then:

- **Found** → an existing KB. Switch to **caretaker mode** (Step 6). Never re-run the wizard over a live KB.
- **Not found** → fresh ground. Run the wizard (Step 2). This is also exactly what the **SessionStart hook** reports: when no `kb-config.yml` exists, it prints a gentle "no knowledge base here — run /knowledge-base to set one up" and stops. It *offers*, never auto-builds.

## Step 2: Choose the backend (the wizard)

Interview the user **one question at a time**, plainly, recommending an answer with its reasoning. Lead with the analogy:

> *"A knowledge base is just where your team keeps what it knows and what it's working on. You can keep it three ways — like a shared folder of files on your computer (**local**), like a filing cabinet of labelled tickets (**GitHub** issues + labels), or like a Notion workspace of linked pages and tables (**Notion**). Many teams split it: live work in GitHub, lasting knowledge in Notion or local files (**hybrid**)."*

Ground every question in a **live example** — e.g. *"Say we're starting the 'inviscel' knowledge base today. When you decide something important, like 'we'll position Forge on top of AIP', where would you want to find that written down later?"* Cover, in order:

1. **Backend** — local · GitHub · Notion · hybrid. *Recommend hybrid (GitHub + Notion)* for a team that already uses GitHub; *recommend local* for a solo founder who wants files they own outright.
2. **The hybrid split (if hybrid)** — fixed: **GitHub runs the live pipeline** (Issues + `type:*`/`state:*` labels), the **other half holds durable knowledge** (vision, architecture, glossary, PRDs, ADRs, memories). Confirm which half holds knowledge — Notion or local.
3. **Coordinates** — the GitHub repo (`owner/name`) and/or the Notion parent page. Explore first: `gh repo view` may already answer the repo.

The full menu, what each backend physically creates, and the hybrid mapping are in [REFERENCE.md](REFERENCE.md).

## Step 3: Record the preference

Write `kb-config.yml` at the KB root — the single source of truth the hook and every other skill read. Shape and fields are in [REFERENCE.md](REFERENCE.md#kb-configyml). One name per concept; absolute dates only.

## Step 4: Scaffold the full pipeline

Run the deterministic setup for the chosen backend — this builds the *whole* idea-to-merge structure so `ideate`→`review-pr` work the moment it finishes:

- **Local** → `scripts/scaffold-local.sh <ORG_KB>` — the numbered-folder vault, every folder's `index.md`, `00-meta/conventions.md`, and document templates.
- **GitHub** → `scripts/setup-github-labels.sh <owner/repo>` — the control-plane labels and `Bug`/`Feature` issue types.
- **Notion** → create one database per pipeline doc-type via the Notion MCP (`notion-create-database`), per [REFERENCE.md](REFERENCE.md#notion).
- **Hybrid** → run the GitHub script **and** the knowledge half (Notion databases or `scaffold-local.sh`), wiring each to the other.

Then, for **every** backend, create a project-tier `.instincts/` folder so portable coding preferences travel with the repo. You only scaffold the empty folder — the `instincts` skill owns what goes inside it and the always-on apply loop. This is a developer-experience win: agents pick up the team's coding instincts automatically, no re-explaining.

## Step 5: Wire ownership through AGENTS.md

Create or update `AGENTS.md` (and `CLAUDE.md` as `@AGENTS.md`) with a **Knowledge Base** pointer block: the backend, where the pipeline lives, where durable knowledge lives, and the line *"KB structure owned by the `knowledge-base` skill; backend recorded in `kb-config.yml`."* Keep AGENTS.md short — add a link, not content. Also seed the **instincts index block** (between `<!-- instincts:index:start -->` / `:end -->` markers) by running the `instincts` skill's `scripts/index.sh` — that block drives the always-on apply loop and stays owned by the `instincts` skill. Then install the detect-and-offer hook with `scripts/install-hook.sh`.

## Step 6: Caretaker mode (existing KB)

When Step 1 finds a KB, you're maintaining, not building. Read `kb-config.yml`, then offer only what's needed: add a missing folder/label/database, repair frontmatter or index drift, or **migrate** a backend (e.g. local → hybrid). Every change is additive or a repair; anything that would drop or overwrite data is surfaced and waits for an explicit human yes. Stamp any comment or summary with `> **🧭 knowledge-base-agent**`.

## Marker & human gate

- **Marker:** `> **🧭 knowledge-base-agent**` (registered in the README "Comment markers" table — unique to this skill).
- **Human gate:** confirmation before any write that overwrites or deletes. The wizard runs only on fresh ground or by explicit invocation; the hook offers and never auto-builds. This skill never applies pipeline `state:*` gate labels.
