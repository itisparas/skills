---
name: review-pr
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this organisation's documented coding standards?) and Spec (does the code match what the originating issue/PRD asked for, relevant PRDs, and ADRs?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to "review since X".
---

# Review

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this organisation's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

## Prerequisites

- You must have a knowledge base for the organisation and set an environment variable `ORG_KB` for the current working directory (e.g., `export ORG_KB=./`).
- The `gh` CLI must be authorised (`gh auth status`)
- Check that Notion MCP tool is installed and configured for this organisation. If any Notion MCP tool call fails, set it up first:

```bash
# For Codex CLI
codex mcp add notion --url https://mcp.notion.com/mcp
codex --enable rmcp_client
codex mcp login notion

# For Claude Code
claude mcp add --transport http notion https://mcp.notion.com/mcp
# Then authenticate by running /mcp and following the OAuth flow.
```

After login/restart, retry the original task. If it still fails, check the Notion MCP tool configuration and ensure that the correct credentials are being used.

## Running lean

Keep the review token-cheap and the context window small:

- **Don't read the diff yourself.** Pass the diff *command* to the sub-agents and let each read only what it needs. The main agent orchestrates; it doesn't load the whole diff into its own context.
- **Search narrow.** Gather the standards/spec file list with targeted lookups, not by reading every candidate file. When searching **code** (locating constructs, checking a standard is followed), use `ast-grep` (`sg`) for structural matches, never plain `grep` — see the `ast-grep` skill. Keyword search is only for prose docs.
- **Lean sub-agents.** The 400-word caps below are deliberate — keep them. Ask for findings, not echoed code.
- **Terse internally, plain to the user.** Your own scratch notes can be caveman-terse (drop articles/filler, `X -> Y` for cause). The final report and any PR comment stay plain enough for a non-technical stakeholder to follow.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. Don't be opinionated; pass it through. If they didn't specify one, ask: "Review against what — a branch, a commit, or `main`?" Don't proceed until you have it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

Then resolve the PR for the current branch: `gh pr view --json number,url,headRefName`. Capture the PR number for the tagging step in §5. If the branch has **no** open PR, the review still runs — but the tag/comment actions in §5 are skipped and you present the report inline instead.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. The issue that triggered the PR, if any. If the PR is linked to an issue, fetch the issue body and any linked PRDs/specs/ADRs.
2. A path the user passed as an argument.
3. A PRD/spec file under organisation in Notion or `$ORG_KB/docs/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the $ORG_KB or project repo that documents how code should be written. Common locations:

- `CLAUDE.md`, `AGENTS.md`
- `CONTRIBUTING.md`
- `CONTEXT.md`, `CONTEXT-MAP.md`, per-context `CONTEXT.md` files
- ADRs in Notion or `$ORG_KB/docs/adr/` (architectural decisions are standards)
- `.editorconfig`, `eslint.config.*`, `biome.json`, `prettier.config.*`, `tsconfig.json` (machine-enforced standards — note them but don't re-check what tooling already checks)
- Any `STYLE.md`, `STANDARDS.md`, `STYLEGUIDE.md`, or similar at the repo root or under `docs/`

Collect the list of files. The **Standards** sub-agent will read them.

### 4. Spawn both sub-agents in parallel

Send a single message with two `Agent` tool calls. Use the `general-purpose` subagent for both.

**Standards sub-agent prompt** — include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3.
- The brief: "Read the standards docs. Then read the diff. Report — per file/hunk where relevant — every place the diff violates a documented standard. Cite the standard (file + the rule). Distinguish hard violations from judgement calls. Skip anything tooling enforces. For any code search, use `ast-grep` (`sg`) for structural matches, not `grep`. Under 400 words."

**Spec sub-agent prompt** — include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Read the spec. Then read the diff. Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. For any code search, use `ast-grep` (`sg`) for structural matches, not `grep`. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings — the two axes are deliberately separate so the user can see them independently.

If there is a major issue in either axis, tag the PR with `state:blocked` and add a comment summarising the findings. If both axes are clean, tag the PR with `state:merge-ready`.

If there are any findings that require human judgement and cannot be automatically resolved, tag the PR with `state:human-review-needed` and add a comment summarising the findings or creating a follow-up issue with reference to the PR and `state:human-review-needed` label.

Refer to the open issues in the repo for any known problems that may affect the review. If any of the findings are already known issues, note them in the final report.

End with a one-line summary in plain language a non-technical stakeholder can follow: total findings per axis, the worst single issue (if any) flagged, new issues created (if any).

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
