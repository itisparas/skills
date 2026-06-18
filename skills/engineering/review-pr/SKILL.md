---
name: review-pr
description: Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes — Standards (does the code follow this organisation's documented coding standards?) and Spec (does the code match what the originating issue/PRD asked for, relevant PRDs, and ADRs?). Runs both reviews in parallel sub-agents, reports them side by side, then aligns each finding's disposition with the user interview-style (ideate-style, one question at a time) before posting the PR comment. When a code fix is agreed it spawns an implement-issue sub-agent via the Agent tool to make it inline first, then it merges and closes the PR itself. It never edits code directly; only an unresolved judgement call is handed to a human by label. Takes a fixed point/PR the user names, or auto-searches for open PRs carrying state:review-ready and reviews them in batch. Use when the user wants to review a branch, a PR, work-in-progress changes, asks to "review since X", or wants the next review-ready PR picked up.
---

# Review

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this org's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context; this skill aggregates their findings, **aligns the dispositions with the user interview-style** (§5), and only then posts. It **never edits code itself** — but when the interview agrees a code fix, it spawns an `implement-issue` sub-agent (via the **`Agent`** tool) to make that fix **inline, before the comment is posted**, then **merges and closes the PR itself** (§6). Landing the PR is this skill's responsibility, not a human's.

All comments it posts on a PR or issue **must** begin with `> **🔎 review-pr-agent**` — distinguishing it from humans and other skills (`👷 implement-issue-agent`, `⚓️ ideate-agent`). `implement-issue` reads these marked comments to know what to rework.

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

**Label pickup (the build hand-off).** With no fixed point given — `review-pr` with no argument — search for PRs `implement-issue` has handed off and review them one at a time:

```bash
gh pr list --label "state:review-ready" --state open --json number,headRefName --jq '.[].number'
```

For each, the fixed point is the PR's **merge-base with the base branch** (`git merge-base origin/<base> HEAD`). Consume the trigger in §5 (swap `state:review-ready` off as the outcome label goes on) so it isn't re-reviewed.

**User-named point.** Whatever the user said is the fixed point — a commit SHA, branch, tag, `main`, `HEAD~5`. Pass it through; don't be opinionated. If they gave neither a point nor a review-ready PR to pick up, ask: "Review against what — a branch, a commit, or `main`?" Don't proceed without it.

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

### 5. Align with the user, then post

Present the two reports under `## Standards` and `## Spec`, verbatim or lightly cleaned. Do **not** merge or rerank — the axes are deliberately separate. **Do not post anything yet.**

**Decide the disposition with the user, ideate-style** (see the `ideate` skill) — the review's findings are a *proposal*, not a verdict; the comment that lands on the PR must reflect what you and the user agreed. One finding (or one cluster) at a time:

- **Ask, wait, ask the next — never batch.** Plain language, grounded in a live example from *this* diff ("the Spec axis says failed-payment isn't covered — I'd ask `implement-issue` to add that test before merge; agree, or is that out of scope here?").
- **Always recommend a disposition** with reasoning: *fix before merge* / *acceptable, note it* / *not a real finding, drop it* / *needs a human's judgement*.
- Let the user overrule any finding — they may know context the sub-agents didn't. Fold the outcome into the comment you'll post.

Once the dispositions are agreed, **act on them before posting anything** — the comment must describe the PR's *final* state, after fixes:

- **Anything agreed as a code fix (*fix before merge*), during or after the interview** → **don't label-and-wait; fix it inline now** by spawning an `implement-issue` sub-agent (§6a). Loop until **nothing** remains to fix.
- **A disposition you and the user genuinely couldn't settle** → `state:human-review-needed` + the open question in the comment (or a follow-up issue referencing the PR). This is the **only** outcome still handed to a human.
- **Dropped or accepted-and-noted** → nothing to do.

Then **post the marked comment** (`> **🔎 review-pr-agent**`, the per-axis findings, their agreed dispositions, and any fixes the inline sub-agent applied) and **remove `state:review-ready`** — the review consumes the trigger. Check the repo's open issues; if any finding is a known one, note it. End with a one-line plain-language summary: findings per axis, what was agreed, what was fixed inline, whether it merged, the worst single issue (if any), new issues created (if any).

Unless something was parked as `state:human-review-needed`, the PR is now clean — **merge and close it (§6b)**.

### 6. Fix inline, then merge and close

**6a. Trigger the fix — `Agent` tool + `implement-issue`.** When the interview agrees a code change, review-pr drives the fix itself instead of handing off by label:

- Call the **`Agent`** tool (subagent `general-purpose`) telling it to run the **`implement-issue`** skill. Hand it the **PR number and branch**, the **agreed findings verbatim** (per axis), and the review context. Instruct it to rework the PR **test-first** against exactly those findings and push — `implement-issue`'s own rework path.
- When it returns, **verify the fix landed**: re-diff, and for a non-trivial change re-run the affected axis sub-agent over the new diff. If anything is still open, spawn another `implement-issue` pass. **Loop until clean.**
- If the fix plan is at all ambiguous, confirm it with the user before spawning.

**6b. Merge and close — this skill's job.** Once nothing remains to fix and nothing is parked for a human, **review-pr lands the PR — not a human, not a label:**

- Confirm once (a merge is hard to undo): *"Clean and all fixes are in — merging now."*
- Merge with the repo's method and delete the branch: `gh pr merge <n> --squash --delete-branch`. If required checks are still running, add `--auto` so it merges the moment they pass — don't drop the duty back on a human.
- `closes #<issue>` retires the task issue on merge; confirm it closed (`gh pr view <n> --json closingIssuesReferences`) and close it explicitly if it didn't.
- **Only** when the merge needs something review-pr cannot satisfy — branch protection requiring another human's approval — fall back to `state:merge-ready` and say why in the comment. A pending check is **not** that case; wait it out with `--auto`.

## Why two axes

A change can pass one axis and fail the other — code that follows every standard but implements the wrong thing (**Standards pass, Spec fail**), or code that does exactly what the issue asked but breaks conventions (**Spec pass, Standards fail**). Reporting them separately stops one from masking the other.
