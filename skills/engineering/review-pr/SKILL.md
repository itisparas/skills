---
name: review-pr
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this organisation's documented coding standards?) and Spec (does the code match what the originating issue/PRD asked for, relevant PRDs, and ADRs?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
---

# Review

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this org's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context; this skill aggregates their findings.

## Prerequisites

- A knowledge base for the org, with `ORG_KB` set to the working directory (e.g. `export ORG_KB=./`).
- `gh` CLI authorised (`gh auth status`).
- Notion MCP installed and configured. If a Notion MCP call fails, set it up, then retry:

```bash
# Codex CLI
codex mcp add notion --url https://mcp.notion.com/mcp && codex --enable rmcp_client && codex mcp login notion
# Claude Code
claude mcp add --transport http notion https://mcp.notion.com/mcp   # then run /mcp and follow OAuth
```

## Running lean

- **Don't read the diff yourself.** Pass the diff *command* to the sub-agents; each reads only what it needs. The main agent orchestrates.
- **Search narrow.** Gather the standards/spec file list with targeted lookups, not by reading every candidate. For **code** use `ast-grep` (`sg`), never `grep` (see the `ast-grep` skill); keyword search is only for prose.
- **Lean sub-agents.** The 400-word caps below are deliberate — keep them. Ask for findings, not echoed code.
- **Terse internally, plain to the user.** Scratch notes can be caveman-terse (`X -> Y`); the final report and any PR comment stay plain enough for a non-technical stakeholder.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch, tag, `main`, `HEAD~5`. Pass it through; don't be opinionated. If they gave none, ask: "Review against what — a branch, a commit, or `main`?" Don't proceed without it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, against the merge-base); note commits via `git log <fixed-point>..HEAD --oneline`. Then resolve the PR: `gh pr view --json number,url,headRefName` — capture the number for §5. If the branch has **no** open PR, the review still runs but §5's tag/comment actions are skipped and you present the report inline.

### 2. Identify the spec source

In order: (1) the issue that triggered the PR, plus any linked PRDs/specs/ADRs; (2) a path the user passed; (3) a PRD/spec in Notion or `$ORG_KB/docs/` matching the branch/feature; (4) if nothing is found, ask the user — if they say there's no spec, the **Spec** sub-agent skips and reports "no spec available".

### 3. Identify the standards sources

Anything in `$ORG_KB` or the repo that documents how code should be written:

- `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`
- `CONTEXT.md`, `CONTEXT-MAP.md`, per-context `CONTEXT.md` files
- ADRs in Notion or `$ORG_KB/docs/adr/` (architectural decisions are standards)
- `.editorconfig`, `eslint.config.*`, `biome.json`, `prettier.config.*`, `tsconfig.json` (machine-enforced — note them, but don't re-check what tooling already checks)
- Any `STYLE.md` / `STANDARDS.md` / `STYLEGUIDE.md` at the root or under `docs/`

Collect the file list for the **Standards** sub-agent.

### 4. Spawn both sub-agents in parallel

Send a single message with two `Agent` tool calls, `general-purpose` for both.

**Standards sub-agent** — include the full diff command + commit list, the standards-source files from step 3, and: "Read the standards docs, then the diff. Report — per file/hunk where relevant — every place the diff violates a documented standard. Cite the standard (file + rule). Distinguish hard violations from judgement calls. Skip anything tooling enforces. For code search use `ast-grep` (`sg`), not `grep`. Under 400 words."

**Spec sub-agent** — include the diff command + commit list, the spec path/contents, and: "Read the spec, then the diff. Report: (a) requirements asked for that are missing or partial; (b) behaviour not asked for (scope creep); (c) requirements that look implemented but wrong. Quote the spec line for each. For code search use `ast-grep` (`sg`), not `grep`. Under 400 words." If the spec is missing, skip this sub-agent and note it in the report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec`, verbatim or lightly cleaned. Do **not** merge or rerank — the axes are deliberately separate.

- Major issue in either axis → tag the PR `state:blocked` + a comment summarising findings.
- Both axes clean → tag `state:merge-ready`.
- Findings needing human judgement that can't be auto-resolved → tag `state:human-review-needed` + a comment summarising them, or a follow-up issue referencing the PR with that label.

Check the repo's open issues for known problems; if any finding is a known issue, note it. End with a one-line plain-language summary a non-technical stakeholder can follow: total findings per axis, the worst single issue (if any), new issues created (if any).

## Why two axes

A change can pass one axis and fail the other — code that follows every standard but implements the wrong thing (**Standards pass, Spec fail**), or code that does exactly what the issue asked but breaks conventions (**Spec pass, Standards fail**). Reporting them separately stops one from masking the other.
