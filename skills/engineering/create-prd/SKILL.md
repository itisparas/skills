---
name: create-prd
description: Expand a gated brief into a durable PRD. Takes a specific issue number, or auto-searches the repository for open type:brief issues carrying the state:prd-ready label and processes them in batch. Investigates the codebase in a sub-agent, then writes and publishes a PRD of decisions. The step between ideate (brief) and implement-issue (implementation). Use when a brief is ready to be specced — e.g. "create prd", "create prd 250", "write the PRD for this brief", "spec this out".
---

# Create PRD

Turn a brief into a Product Requirements Document — the **second** step of the idea-to-merge flow: `ideate` writes a lean brief ("should we?"), **`create-prd` expands it into a durable spec** ("what exactly to build"), and `implement-issue` implements it after a human gate. The brief is thin; the PRD is where the problem becomes concrete and buildable — grounded in the codebase but written to outlive any file layout.

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

## Everything routes through labels and markers

Never guess the next step from prose. **Every branch — which briefs to pick up, whether one is authorised, when a human is needed — is decided by a GitHub label; every comment is stamped with the marker.** The README's "Labels" and "Comment markers" tables are the single source of truth.

- **`state:prd-ready`** — **human gate in.** A human applies it to a `type:brief` to authorise a PRD; batch mode only picks up briefs carrying it.
- **`state:human-review-needed`** — applied by this skill to a brief on a blocking open question (Step 3); how it asks for a human.
- **`state:agent-ready`** — **human gate out**, applied to the PRD before build. This skill **never** applies it.

## Agent Comment Marker

All comments and PRD bodies **must** begin with `> **📐 create-prd-agent**` — distinguishing it from humans and other skills (`⚓️ ideate-agent`, `👷 implement-issue-agent`).

## Running lean

- **Don't read the codebase yourself.** The deep read happens in a **sub-agent** (Step 2); the main agent orchestrates and never loads the codebase.
- **Load once.** Read the brief, glossary (`CONTEXT.md`), and relevant ADRs once in Step 1; work from a short summary.
- **Search narrow.** For **code** use `ast-grep` (`sg`), never `grep` (common patterns in the `ast-grep` skill's REFERENCE.md); keyword search is only for **prose**.
- **Terse internally, plain to the user.** Scratch reasoning can be caveman-terse (`X -> Y`; see `caveman`). Everything the user reads — questions and the PRD — stays plain and example-driven.

## Invocation modes

**Single brief** — `create prd 250` / `create prd #250`: expand one brief. An explicit number **is** the authorisation, so it runs regardless of `state:prd-ready`. Strip any leading `#`, then go to Step 1.

**Batch** — `create prd`: process every gated brief in sequence, then report each one's outcome (PRD written + brief retired / held for human input / skipped). Run Steps 1–7 for each.

```bash
gh issue list --label "type:brief" --label "state:prd-ready" --state open --json number,title --jq '.[].number'
```

## Step 1: Locate and load the brief

```bash
gh issue view <id> --json title,body,labels,comments
```

- **No brief / wrong type** — say so, recommend `ideate` first; don't invent a problem statement.
- **A `type:prd` already links this brief** — report it and stop unless a human asks for a revision.
- **A prior `📐 create-prd-agent` comment exists** — read the **newer human replies** for the answers, then continue.

Then load the glossary (`CONTEXT.md` / per-context files) and any ADRs in the affected area, so the PRD speaks the org's language and respects recorded decisions.

## Step 2: Investigate the codebase (sub-agent)

Spawn a **`general-purpose` sub-agent** (`Agent` tool) to map the brief onto the code, keeping the heavy read out of the main context. Give it the brief's problem + acceptance criteria, the relevant glossary terms and ADRs, and this brief:

> "Investigate how this would be built. Identify the components/subsystems involved (read the code to confirm, don't guess from names). Map current behaviour and the seams where the change lands. Assess feasibility — **Low** (isolated, <3 files), **Medium** (multi-component, some design calls), **High** (cross-cutting, architectural). Surface risks, edge cases, and any decision needing human judgement. Note existing patterns to follow and the test patterns used here. Use `ast-grep` (`sg`), not `grep`. Return decisions and prose — **no file:line dumps**. Under 500 words."

Fold what it returns into the PRD's *Implementation Decisions* and *Testing Decisions* — durable choices, not file paths (which rot; `implement-issue` re-investigates against the gated PRD).

## Step 3: Resolve open questions

The brief carries `ideate`'s shared understanding, so **don't re-litigate what's settled.** But the investigation may surface genuinely-open questions — a design decision, an ambiguous requirement, a seam choice — that block a sound PRD. Resolve these by **interviewing the human, ideate-style**, never by guessing.

**A human is present (interactive run)** — run an `ideate`-style interview (see the `ideate` skill): one question at a time (ask, wait, ask the next — never batch); always recommend an answer with reasoning; plain words grounded in a **live example** ("I'd test this where an order is *placed*, not inside each payment step, so we check the outcome a customer sees — does that match?"); explore the brief/`ORG_KB`/ADRs/code before asking; resolve dependencies upstream-first.

As answers land, **update the brief inline** so it becomes spec-ready. The interview is what carries the brief (back) to `state:prd-ready`; an explicit interactive run is its own authorisation, so once resolved, continue to Step 4. If the brief was parked, swap the label back:

```bash
gh issue edit <id> --remove-label "state:human-review-needed" --add-label "state:prd-ready"
```

**No human present (batch, or the human defers)** — do **not** guess. Park the brief with the open questions, then route by label:

```bash
gh issue comment <id> --body "> **📐 create-prd-agent**
> ## Open questions before I can write the PRD
> These need a short interview to resolve — re-run \`create prd <id>\` (or reply) and I'll walk through them one at a time.
> 1. <question, with a concrete example and your recommended answer>
> 2. …"
gh issue edit <id> --add-label "state:human-review-needed" --remove-label "state:prd-ready"
```

Then **skip this brief** and move on. Removing `state:prd-ready` drops it from the batch queue; it returns only when the interview above resolves the questions and re-applies the label. Non-blocking questions don't gate anything — carry them into the PRD's *Risks & Open Questions*.

## Step 4: Route to the right doc store

The PRD is a **new artifact** — never rewrite the brief into a PRD in place; they're different types for different readers. It lives wherever the brief lives:

- **GitHub** — an issue labelled `type:prd` (default), cross-linking the brief ("Expands #<brief>").
- **Notion** — a PRD page via the Notion MCP tool, linked to the brief page.
- **Local KB** — a file under `$ORG_KB/` (e.g. `$ORG_KB/docs/prds/`).

The brief is **retired** once the PRD exists — see Step 6.

## Step 5: Write the PRD

Write for a non-technical stakeholder first, an engineer second; use the glossary's terms. Keep it about **decisions**, not code — file paths and snippets go stale.

```markdown
> **📐 create-prd-agent**

## Problem Statement
<the problem from the user's perspective — refined from the brief, 2–4 sentences>

## Solution
<the solution from the user's perspective — what changes for them>

## User Stories
<a long, numbered list covering all aspects of the feature>
1. As a <actor>, I want <feature>, so that <benefit>
2. …

## Implementation Decisions
- <modules to build/modify and their interfaces — described, not pathed>
- <architectural decisions, schema changes, API contracts, key interactions>
(No file paths or code. Exception: if a decision is captured more precisely by a small
snippet — a state machine, schema, or type shape — inline just that decision-rich bit.)

## Testing Decisions
- <what a good test looks like here: external behaviour, not implementation detail>
- <the test seams agreed in Step 3, and the existing prior art to follow>

## Scope Assessment
- **Complexity:** <Low / Medium / High>
- **Confidence:** <High / Medium / Low>

## Out of Scope
- <what this PRD deliberately does not cover>

## Risks & Open Questions
- <anything still needing human judgement before or during the build>

## Further Notes
- <anything else worth recording>
```

Post or update the PRD in the Step 4 destination. If a relevant PRD already exists, refine it rather than duplicating.

## Step 6: Retire the superseded brief

Once the PRD is posted it's the single source of truth, so the pipeline carries one live artifact. Retire the brief, cross-linked both ways, **only after the PRD exists**:

- **GitHub** — comment with the marker + PRD link, then close:

```bash
gh issue comment <brief> --body "> **📐 create-prd-agent**
> Specced into PRD #<prd> — closing this brief. The PRD is now the source of truth."
gh issue close <brief> --reason completed
```

- **Notion** — add a "Superseded by <PRD link>" line at the top of the brief page, then archive it (Notion trash).
- **Local KB** — add a "Superseded by <PRD link>" line at the top of the brief file, then move it to an archive folder (e.g. `$ORG_KB/docs/briefs/archive/`).

The brief is kept, not deleted — closed/archived **is** "retired", and stays cross-linked. If you only **refined an existing PRD** (Step 5), the brief was already retired on the first run — skip this.

## Step 7: Stop at the human gate

Report: the PRD location (clickable link), that the brief was retired, a 2–3 sentence summary, the complexity/confidence call, and the top risk a human should weigh. **Never apply `state:agent-ready`** — state plainly that a human must review and gate the PRD before `implement-issue` picks it up.

## Relationship to other skills

```
Raw idea → ideate → brief (type:brief)
                      │  human applies state:prd-ready   ← gate in
                  create-prd  ← this skill — expands the brief into a PRD (type:prd)
                      │  human applies state:agent-ready ← gate out
              implement-issue → PR → review-pr
```

- **ideate** decides *whether* and writes the lean brief.
- **create-prd** decides *what exactly* and writes the durable PRD.
- **implement-issue** decides *how* and implements — only after a human gates the PRD.
