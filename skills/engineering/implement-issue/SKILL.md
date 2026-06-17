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
- `ast-grep` (`sg`) for all code search — see the `ast-grep` skill.
- Notion MCP only if this org's PRD/brief live in Notion (setup block in `create-prd`).

## Running lean

- **Load once.** Read the task issue, its parent PRD, the brief, and (in rework) the PR's review comments in Step 2; hold a short summary and reference it — don't re-fetch.
- **Search narrow.** Use `ast-grep` (`sg`) for code, never `grep`; keyword search only for prose. Push a big codebase read into a **sub-agent** that returns a short map.
- **Stable prefix.** Keep loaded context fixed across the red-green-refactor loop so prompt caching stays warm.
- **Terse internal, plain to the user.** Scratch reasoning can be caveman-terse (see `caveman`); the PR body, comments, and report stay plain and complete.

## Step 1: Resolve the input — fresh build or rework?

**A PR was named** — `implement pr 251` / a PR URL: **rework mode.** Fetch the PR, the issue it closes (`Closes #<id>`), and `review-pr`'s `> **🔎 review-pr-agent**` comments on it. Go to Step 2.

**A task number, or batch** (`implement` with no arg → `gh issue list --label "type:task" --label "state:agent-ready" --state open --json number`): check the issue's comments for this skill's own `> **👷 implement-issue-agent**` marker.

- **Marker present** → a PR already exists for this issue: **rework mode.** Open the PR linked in that comment, read `review-pr`'s findings, go to Step 2.
- **No marker** → **fresh build.** Claim the issue so nothing double-picks it:

```bash
gh issue edit <id> --add-label "state:building" --remove-label "state:agent-ready"
```

## Step 2: Load context

Read the task issue in full — its **Definition of Ready / Acceptance Criteria / Definition of Done** are the contract. Follow its **Parent** links to the PRD (durable decisions, seams) and brief (intent). Load the `ORG_KB` glossary, relevant ADRs, and the repo's documented coding standards (the same ones `review-pr` checks) so the work passes review first time. **In rework**, also read every `> **🔎 review-pr-agent**` comment on the PR — those findings are already aligned with the user (review-pr interviews them before posting), so treat each as agreed work to do.

## Step 3: Plan against the checklists — gate if not ready

Check the **Definition of Ready** (fresh build) or that the review findings are clear enough to act on (rework). If a precondition is unmet, a requirement is ambiguous, or a design call the PRD left open blocks sound work, **do not guess** — park for a human (Step 5). Otherwise turn the work into a short ordered list of behaviours to drive out test-first. For a fresh build, cut a feature branch (`git switch -c feat/<id>-<slug>`); for rework, check out the PR's existing branch.

## Step 4: Build test-first (red → green → refactor)

Work **one item at a time** — an Acceptance Criterion (fresh build) or a review finding (rework) — through a strict red-green-refactor loop. It's like writing the exam question before the answer: the failing test states exactly what "done" means, then you write just enough code to pass it, then tidy up with the test as a safety net. After each item, run the repo's feedback loops (lint, typecheck, test) and commit small, referencing the issue. The full loop, finding the test command, and handling items that resist a test are in **[REFERENCE.md](REFERENCE.md)**.

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

Report: the issue (link), the PR opened or updated (link) and that it carries `state:review-ready` for `review-pr`, the branch, which Acceptance Criteria or review findings are now covered by tests, and any known follow-up. In batch, one line per task — built / reworked / parked (blocked) / parked (needs human).

```
slice-prd ─ type:task + state:sliced
                      │  human applies state:agent-ready   ← gate in (human-only)
                      ▼
              implement-issue ── claims with state:building ──▶ PR (Closes #id)
                      ▲          hard fail → state:blocked · needs judgement → state:human-review-needed
                      │                                  │
   rework against 🔎 review-pr findings           PR labelled state:review-ready  ← hand-off (no direct call)
                      │                                  ▼
                      └──────────────────────────── review-pr  (picks up state:review-ready, posts 🔎 findings)
```
