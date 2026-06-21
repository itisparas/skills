---
name: implement-issue
description: Take a gated task issue all the way to a review-ready pull request, and rework that PR when review comes back. Builds test-first (red-green-refactor through the Acceptance Criteria) on a feature branch and opens a PR that closes the issue, labelled state:review-ready for review-pr. On a later run — when the issue already carries this skill's own marker comment, or when given a PR — it reads review-pr's findings on the PR and reworks the code to address them, then hands back for re-review. Takes an issue number, a PR, or auto-searches open type:task issues carrying the human gate state:agent-ready. The step between slice-prd (tasks) and review-pr (review), looping with review-pr until the PR is merge-ready. Use when a task is approved to build, or a reviewed PR needs the requested changes — e.g. "implement", "implement 250", "implement issue 250", "implement pr 251", "address the review", "rework this PR".
---

# Implement an issue

The **implementer.** It picks up a task a human gated for building and drives it to a **review-ready** PR — writing tests first, red-green-refactor — then, after `review-pr` posts its findings, it comes back and **reworks** the PR to address them. It never decides *what* to build (a human gated that) and never reviews its own work (`review-pr` does that): it loops with `review-pr` — build → review → rework → re-review — until the PR is merge-ready.

## Labels and markers this skill reads and sets

- **`state:agent-ready`** — **human gate in.** A human applies it to a `type:task` to authorise building; batch mode only picks up tasks carrying it. This skill **never** applies it — it reads it, and removes it when it claims the work.
- **`state:building`** — **set by this skill** when it starts a fresh build: it swaps `state:agent-ready` → `state:building` to claim the issue and drop it from the batch queue. Removed when the work parks; retired with the issue when its PR closes it.
- **`state:review-ready`** — **set by this skill on the PR**, both when it first opens the PR and after each rework round. It's the hand-off: `review-pr` picks up PRs carrying it.
- **`state:blocked` / `state:human-review-needed`** — set when a build or rework can't finish (Step 5).
- **Markers it reads:** its own `> **👷 implement-issue-agent**` comment on an issue signals *a PR already exists* (→ rework); `review-pr`'s `> **🔎 review-pr-agent**` comments on the PR are the findings to rework against.

## Prerequisites

- `gh` CLI authorised (`gh auth status`) — reads issues/PRs, edits labels, opens the PR.
- `ORG_KB` set — glossary (`CONTEXT.md` / `CONTEXT-MAP.md`), ADRs (`docs/adr/` or Notion), documented coding standards. Loaded once.
- `ast-grep` (`sg`) for all code search — common patterns in the `ast-grep` skill's REFERENCE.md.
- Project-tier **`.instincts/`** — portable coding preferences, loaded in Step 2 and applied during the build so the code matches the team's preferences first time (fewer review-rework loops). If the folder is **absent**, bootstrap it via the **`instincts`** skill before building.
- Notion MCP only if this org's PRD/brief live in Notion (setup block in `create-prd`).

## Running lean

- **Load once.** Read the task issue, its parent PRD, the brief, the `.instincts/` rules, and (in rework) the PR's review comments in Step 2; hold a short summary and reference it — don't re-fetch.
- **Search narrow.** Use `ast-grep` (`sg`) for code, never `grep`; keyword search only for prose. Push a big codebase read into the **`kb-investigator`** agent (read-only, Haiku — purpose: build map) that returns a short map. **Tiering:** reads/reviews go cheap; **the build itself writes code, so it stays on the strong (Opus) model** — don't downgrade the implementer.
- **Context budget (≤150k, soft).** Hold summaries, not raw dumps. If the window approaches ~150k tokens during a long build, off-load the next codebase read to a fresh `kb-investigator` sub-agent rather than growing context.
- **Stable prefix.** Keep loaded context fixed across the red-green-refactor loop so prompt caching stays warm.
- **Be concise, sacrifice grammar for the sake of concision.** Internally and in-session, caveman-terse (see `caveman`); the PR body, comments, and report still stay plain and complete.

## Step 1: Resolve the input — fresh build or rework?

**A PR was named** — `implement pr 251` / a PR URL: **rework mode.** Fetch the PR, the issue it closes (`Closes #<id>`), and `review-pr`'s `> **🔎 review-pr-agent**` comments on it. Go to Step 2.

**A task number, or batch** (`implement` with no arg → `gh issue list --label "type:task" --label "state:agent-ready" --state open --json number`): check the issue's comments for this skill's own `> **👷 implement-issue-agent**` marker.

- **Marker present** → a PR already exists for this issue: **rework mode.** Open the PR linked in that comment, read `review-pr`'s findings, go to Step 2.
- **No marker** → **fresh build.** Claim the issue so nothing double-picks it:

```bash
gh issue edit <id> --add-label "state:building" --remove-label "state:agent-ready"
```

## Step 2: Load context

Read the task issue in full — its **Definition of Ready / Acceptance Criteria / Definition of Done** are the contract. Follow its **Parent** links to the PRD (durable decisions, seams) and brief (intent). Load the `ORG_KB` glossary, relevant ADRs, the repo's documented coding standards, **and the project-tier `.instincts/` rules** (the same standards + preferences `review-pr` checks) so the work passes review first time. If `.instincts/` doesn't exist yet, **bootstrap it via the `instincts` skill** before building. **In rework**, also read every `> **🔎 review-pr-agent**` comment on the PR — those findings are already aligned with the user (review-pr interviews them before posting), so treat each as agreed work to do.

## Step 3: Plan against the checklists — gate if not ready

Walk the **Definition of Ready** as a hard gate (fresh build) — **every** box must hold: behaviour unambiguous, preconditions explicit, blockers merged, glossary/ADRs linked, test seam **and the exact test command** known, `.instincts/` rules in scope identified. For rework, the review findings must be clear enough to act on. If **any** box fails — a precondition unmet, a requirement ambiguous, the test command unknown, or a design call the PRD left open — **do not guess and do not build a partial**: park for a human (Step 5). Guessing here is the dominant source of rework loops. Only when the gate fully passes, turn the work into a short ordered list of behaviours to drive out test-first.

**Resolve the build map — don't explore in-session.** The issue carries a durable **Implementation Map** (component-level, `US#`-tagged) from `slice-prd`. Rather than reading the codebase yourself on the strong model, spawn **`kb-investigator`** (`Agent` tool, `subagent_type: kb-investigator`, **purpose: build map**) and hand it that map to **resolve to current file:line targets** in build order. Build against the tight map it returns — the heavy read stays on the cheap model, the strong-model session stays lean (this is the main per-build token saving). If the issue has no map (older slice), it resolves from the Acceptance Criteria as before. For a fresh build, cut a feature branch (`git switch -c feat/<id>-<slug>`); for rework, check out the PR's existing branch.

## Step 4: Build test-first (red → green → refactor)

Work **one item at a time** — an Acceptance Criterion (fresh build) or a review finding (rework) — through a strict red-green-refactor loop, **naming each test after the Acceptance Criterion / `US#` it drives out** so the test threads back to the requirement. It's like writing the exam question before the answer: the failing test states exactly what "done" means, then you write just enough code to pass it, then tidy up with the test as a safety net. Write the code to the documented standards **and the `.instincts/` rules** as you go — matching them now is what stops `review-pr` from bouncing the PR back. After each item, run the repo's feedback loops (lint, typecheck, test) and commit small, referencing the issue. The full loop, finding the test command, and handling items that resist a test are in **[REFERENCE.md](REFERENCE.md)**.

## Step 5: When you can't finish — route by label

Never leave half-built work silently. Drop `state:building` and park by label, with a marked comment saying where it stands:

- **Hard technical failure** (won't go green, broken dependency, environment): `state:blocked`.
- **Needs a person's judgement** (DoR unmet, ambiguous requirement or finding, unsettled design call): `state:human-review-needed`.

```bash
gh issue comment <id> --body "> **👷 implement-issue-agent**
> ## Parked: <one-line reason>
> <what's done, what's blocking, what a human needs to decide — with a concrete example>"
gh issue edit <id> --add-label "state:blocked" --remove-label "state:building"   # or state:human-review-needed
```

A human resolves it and re-applies `state:agent-ready` to authorise a retry. **Never** re-apply `state:agent-ready` yourself.

## Step 6: Open (or update) the PR and hand back to review

When every item is green and the feedback loops pass, push the branch. On a **fresh build**, open a PR whose body **closes the issue** (`Closes #<id>`) and cross-links the PRD and brief (template in **[EXAMPLES.md](EXAMPLES.md)**); on **rework**, push to the existing branch and add a marked comment on the PR summarising what changed per finding. Either way, label the **PR** `state:review-ready` (removing `state:blocked` if it was set) to hand back to `review-pr`, and post/refresh the marker comment on the **issue** so the next run knows a PR exists:

```bash
gh pr edit <pr> --add-label "state:review-ready" --remove-label "state:blocked"
gh issue comment <id> --body "> **👷 implement-issue-agent**
> Built → PR #<pr> (\`state:review-ready\`). Re-run me on this issue, or give me the PR, to pick up review feedback."
```

## Report

Report: the issue (link), the PR opened or updated (link) and that it carries `state:review-ready` for `review-pr`, the branch, which **`US#`** requirements (and review findings) are now covered by tests, and any known follow-up. In batch, one line per task — built / reworked / parked (blocked) / parked (needs human).

```
slice-prd ─ type:task + state:buildable
                      │  human applies state:agent-ready   ← gate in (human-only)
                      ▼
              implement-issue ── claims with state:building ──▶ PR (Closes #id)
                      ▲          hard fail → state:blocked · needs judgement → state:human-review-needed
                      │                                  │
   rework against 🔎 review-pr findings           PR labelled state:review-ready  ← hand-off (no direct call)
                      │                                  ▼
                      └──────────────────────────── review-pr  (picks up state:review-ready, posts 🔎 findings)
```
