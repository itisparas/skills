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

- **`state:prd-ready`** — **human gate in.** A human applies it to a `type:brief` to authorise a PRD; batch mode picks up briefs carrying it.
- **`state:auto-ok`** — **standing human consent** for low-risk auto-advance. A human applies it once on a brief to let the chain carry a *low-risk* item through the cheap gates without per-step clicks. Batch mode also picks up `state:auto-ok` briefs; this skill **propagates** it to the PRD it writes (Step 6) so `slice-prd` can continue — but only when the work is genuinely low-risk (Step 3). It is **not** a human gate, and never substitutes for `state:agent-ready` (the build gate stays human-only).
- **`state:human-review-needed`** — applied by this skill to a brief on a blocking open question (Step 3); how it asks for a human.
- **`state:agent-ready`** — **human gate out**, applied to the PRD before build. This skill **never** applies it.

## Agent Comment Marker

All comments and PRD bodies **must** begin with `> **📐 create-prd-agent**` — distinguishing it from humans and other skills (`⚓️ ideate-agent`, `👷 implement-issue-agent`).

## Running lean

- **Don't read the codebase yourself.** The deep read happens in a **sub-agent** (Step 2) that runs on a cheap, fast model; the main agent orchestrates and never loads the codebase. Reads/reviews go cheap; only code-writing needs the strong model.
- **Context budget (≤150k, soft).** Hold **summaries only** — never the codebase, never raw file dumps. If the window approaches ~150k tokens, spawn a fresh sub-agent rather than grow context. In batch, discard one brief's working notes before starting the next.
- **Load once.** Read the brief, glossary (`CONTEXT.md`), and relevant ADRs once in Step 1; work from a short summary.
- **Search narrow.** For **code** use `ast-grep` (`sg`), never `grep` (common patterns in the `ast-grep` skill's REFERENCE.md); keyword search is only for **prose**.
- **Be concise, sacrifice grammar for the sake of concision.** Internally and in-session, caveman-terse (`X -> Y`; see `caveman`). Everything the user *reads as an artifact* — questions and the PRD — still stays plain and example-driven.

## Invocation modes

**Single brief** — `create prd 250` / `create prd #250`: expand one brief. An explicit number **is** the authorisation, so it runs regardless of `state:prd-ready`. Strip any leading `#`, then go to Step 1.

**Batch** — `create prd`: process every gated brief in sequence, then report each one's outcome (PRD written + brief retired / held for human input / skipped). Run Steps 1–7 for each. Pick up both human-gated (`state:prd-ready`) and standing-consent (`state:auto-ok`) briefs:

```bash
gh issue list --label "type:brief" --label "state:prd-ready" --state open --json number,title --jq '.[].number'
gh issue list --label "type:brief" --label "state:auto-ok"   --state open --json number,title --jq '.[].number'
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

Spawn the **`kb-investigator`** agent (read-only, runs on Haiku — `Agent` tool, `subagent_type: kb-investigator`) to map the brief onto the code, keeping the heavy read out of the main context. Hand it **purpose: feasibility**, the brief's problem + acceptance criteria, and the relevant glossary terms and ADRs. It returns the components/seams, a **Low/Medium/High feasibility rating**, risks, and any decision needing human judgement — ≤500 words, no file:line dumps. *If named subagents aren't supported on this harness, spawn a `general-purpose` sub-agent on a fast model and have it follow `agents/kb-investigator.md`.*

Fold what it returns into the PRD's *Implementation Decisions* and *Testing Decisions* — durable choices, not file paths (which rot; `implement-issue` re-investigates against the gated PRD). The feasibility rating also gates auto-advance (Step 3).

## Step 3: Resolve open questions

The brief carries `ideate`'s shared understanding, so **don't re-litigate what's settled.** But the investigation may surface genuinely-open questions — a design decision, an ambiguous requirement, a seam choice — that block a sound PRD. Resolve these by **interviewing the human, ideate-style**, never by guessing.

**A human is present (interactive run)** — run an `ideate`-style interview (see the `ideate` skill): one question at a time (ask, wait, ask the next — never batch); always recommend an answer with reasoning; plain words grounded in a **live example** ("I'd test this where an order is *placed*, not inside each payment step, so we check the outcome a customer sees — does that match?"); explore the brief/`ORG_KB`/ADRs/code before asking; resolve dependencies upstream-first.

As answers land, **update the brief inline** so it becomes spec-ready. The interview is what carries the brief (back) to `state:prd-ready`; an explicit interactive run is its own authorisation, so once resolved, continue to Step 4. If the brief was parked, swap the label back:

```bash
gh issue edit <id> --remove-label "state:human-review-needed" --add-label "state:prd-ready"
```

**No human present, brief carries `state:auto-ok` (standing consent) — the low-risk auto-advance path.** Only when **both** hold: the `kb-investigator` rated feasibility **Low** *and* there are **no blocking open questions**. Then skip the interview, write the PRD (Steps 4–5), and propagate `state:auto-ok` to it (Step 6) so `slice-prd` continues. If feasibility is **Medium/High**, or any blocking question exists, **do not auto-advance** — fall through to parking below (this is the safety valve: auto-ok never forces a risky item through).

**No human present (batch without `state:auto-ok`, or the human defers)** — do **not** guess. Park the brief with the open questions, then route by label:

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

Write for a non-technical stakeholder first, an engineer second; use the glossary's terms. Keep it about **decisions**, not code — file paths and snippets go stale. The full PRD template (Problem, Solution, User Stories, Implementation/Testing Decisions, Scope, Risks) is in **[EXAMPLES.md](EXAMPLES.md)**.

Post or update the PRD in the Step 4 destination. If a relevant PRD already exists, refine it rather than duplicating. **If the brief carried `state:auto-ok` and the work was low-risk** (Step 3 auto-advance), apply `state:auto-ok` to the new PRD so `slice-prd` can continue the chain — `gh issue edit <prd> --add-label "state:auto-ok"`. Otherwise leave it off; a human gates with `state:slice-ready` as normal.

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
