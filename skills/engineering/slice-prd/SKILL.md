---
name: slice-prd
description: Slice a gated PRD into independently-buildable issues using tracer-bullet vertical slices. Takes a type:prd issue number, or auto-searches for type:prd issues carrying the human gate state:slice-ready and processes them in batch. Investigates the codebase in a sub-agent, interviews the user one question at a time (plain language, analogies, a live example) to set slice coarseness before creating anything, then publishes child issues each with a Definition of Ready / Acceptance Criteria / Definition of Done checklist, cross-linked to the PRD and its brief. Clear slices are flagged state:buildable for a human to gate; ambiguous ones get state:human-review-needed; the PRD itself is marked state:sliced and stays open as the epic. The step between create-prd and implement-issue. Use when a PRD is ready to break into work — e.g. "slice prd", "slice prd 250", "break this PRD into issues", "turn the PRD into tickets".
---

# Slice PRD

Cut a PRD into small, independently-grabbable issues — the **third** step of the idea-to-merge flow: `ideate` writes a lean brief, `create-prd` expands it into a durable PRD, and **`slice-prd` breaks that PRD into buildable tasks** that `implement-issue` picks up one at a time after a human gate. Each slice is a **tracer bullet** — a thin path that cuts through *every* layer end-to-end, not a horizontal slab of one layer — so a finished slice is demoable on its own.

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

Never guess the next step from prose. **Every branch — which PRDs to pick up, whether a slice is buildable or needs a human, when to stop — is decided by a GitHub label; every comment is stamped with the marker.** The README's "Labels" and "Comment markers" tables are the single source of truth.

- **`state:slice-ready`** — **human gate in.** A human applies it to a `type:prd` to authorise slicing; batch mode picks up PRDs carrying it. This skill **never** applies it.
- **`state:auto-ok`** — **standing human consent** (propagated from the brief/PRD by `create-prd`). Batch mode also picks up `state:auto-ok` PRDs and slices them **without** waiting for `state:slice-ready` — but **only when every slice is clear** (no ambiguous slice; Step 4). It stops at slicing: children get `state:buildable` and still wait for a human's `state:agent-ready`. The build gate is **never** auto-advanced.
- **`type:task`** — set by this skill on every child issue it creates.
- **`state:buildable`** — set by this skill on a **clear** child issue: "I judged this slice buildable." It is *not* a build gate — a human still applies `state:agent-ready`.
- **`state:sliced`** — set by this skill on the **PRD itself** (Step 6) the moment it's sliced: "this PRD has been broken down; it's now the open epic tracking its children." It's what tells you (and batch mode) a PRD is done vs still awaiting its gate. Removed only when the PRD closes, once every child has merged.
- **`state:human-review-needed`** — set by this skill in two places: on an **ambiguous child issue** (missing info, unresolved design call) before it can be gated; and on the **PRD itself** (off `state:slice-ready`) to park a breakdown that needs async sign-off when no human is present (Step 4).
- **`state:agent-ready`** — **human gate out**, applied per child issue before build. This skill **never** applies it.

## Agent Comment Marker

All comments and child-issue bodies **must** begin with `> **🔪 slice-prd-agent**` — distinguishing it from humans and other skills (`⚓️ ideate-agent`, `📐 create-prd-agent`, `👷 implement-issue-agent`).

## Running lean

- **Don't read the codebase yourself.** The deep read happens in a **sub-agent** (Step 2) on a cheap, fast model; the main agent orchestrates the interview and never loads the codebase. Reads/reviews go cheap; only code-writing needs the strong model.
- **Context budget (≤150k, soft).** Hold **summaries only** — never the codebase. If the window approaches ~150k tokens, spawn a fresh sub-agent rather than grow context. In batch, discard one PRD's working notes before the next.
- **Load once.** Read the PRD, its brief, the glossary (`CONTEXT.md`), and relevant ADRs once in Step 1; work from a short summary.
- **Search narrow.** For **code** use `ast-grep` (`sg`), never `grep` (common patterns in the `ast-grep` skill's REFERENCE.md); keyword search is only for **prose**.
- **Be concise, sacrifice grammar for the sake of concision.** Internally and in-session, caveman-terse (`X -> Y`; see `caveman`). Everything the user *reads as an artifact* — the interview and the breakdown — still stays plain and example-driven.

## Invocation modes

**Single PRD** — `slice prd 250` / `slice prd #250`: slice one PRD. An explicit number **is** the authorisation, so it runs regardless of `state:slice-ready`. Strip any leading `#`, then go to Step 1.

**Batch** — `slice prd`: process every gated PRD in sequence, reporting each outcome. Run Steps 1–7 for each. Pick up both human-gated (`state:slice-ready`) and standing-consent (`state:auto-ok`) PRDs:

```bash
gh issue list --label "type:prd" --label "state:slice-ready" --state open --json number,title --jq '.[].number'
gh issue list --label "type:prd" --label "state:auto-ok"     --state open --json number,title --jq '.[].number'
```

## Step 1: Locate and load the PRD

```bash
gh issue view <id> --json title,body,labels,comments
```

- **No PRD / wrong type** — say so, recommend `create-prd` first; don't invent a spec.
- **Child `type:task` issues already link this PRD** — report them and stop unless a human asks to slice further.
- **A prior `🔪 slice-prd-agent` comment proposed a breakdown** (the PRD was parked at Step 4) — read the **newer human replies** for their granularity decisions, then continue from those rather than re-drafting from scratch.

Then load the **brief** the PRD expands (follow the "Expands #…" cross-link), the glossary (`CONTEXT.md` / per-context files), and any ADRs in the affected area — so slice titles speak the org's language and respect recorded decisions.

## Step 2: Investigate the codebase (sub-agent)

Spawn the **`kb-investigator`** agent (read-only, runs on Haiku — `Agent` tool, `subagent_type: kb-investigator`) to map the PRD onto the code, keeping the heavy read out of the main context. Hand it **purpose: slicing**, the PRD's user stories + implementation decisions, and the relevant glossary terms and ADRs. It returns the natural seams, a proposed thin-vertical-slice list with dependency order, a per-slice **component-level build map** (ordered steps, no file:line), and any requirement that is **ambiguous, missing information, or needs a design decision** — ≤500 words, no file:line dumps. *If named subagents aren't supported on this harness, spawn a `general-purpose` sub-agent on a fast model and have it follow `agents/kb-investigator.md`.*

Use what it returns to draft the slices (Step 3) and to mark which slices are clear vs ambiguous (Step 5). The presence of **any** ambiguous slice blocks auto-advance (Step 4).

## Step 3: Draft tracer-bullet slices

Break the PRD into **tracer bullets**. Each slice:

- delivers a narrow but **complete** path through every layer — demoable/verifiable on its own;
- is **not** a horizontal slice of one layer ("all the schema", "all the UI");
- prefers **many thin slices over few thick ones**;
- carries a **Blocked by** list (which slices must land first), so they publish in dependency order.

Classify each slice from the Step 2 findings: **clear** (no open questions — will get `state:buildable`) or **needs-a-human** (ambiguous, missing info, or an unresolved design call — will get `state:human-review-needed`). Prefer clear over needs-a-human where the PRD already decided it.

## Step 4: Set the coarseness with the user

Granularity is a judgement call — **never guess it and publish.** The breakdown must be signed off before any child issue is created. There are two surfaces for that sign-off; pick by whether a human is in the room.

The proposed breakdown is always shown as a numbered list — for each slice: **Title · Clear/Needs-a-human · Blocked by · User stories covered**.

**A human is present (interactive run) — the conversation is the surface.** Show the breakdown in chat and agree the granularity interview-style: plain language, grounded in a **live example** from *this* PRD, one small question at a time (ask, wait, ask the next — never batch), always recommending an answer with reasoning (the cake analogy and a full worked interview are in [EXAMPLES.md](EXAMPLES.md)). Walk, one question at a time: is the granularity right (too coarse / too fine)? are the dependencies correct? should any slices merge or split? are the right slices flagged as needing a human? Iterate until the user approves, then go to Step 5. Nothing is written to the tracker until they approve. An explicit interactive run is its own authorisation — if this PRD was previously parked (carries `state:human-review-needed`), swap the label back as you proceed:

```bash
gh issue edit <prd> --remove-label "state:human-review-needed" --add-label "state:slice-ready"
```

**No human present, PRD carries `state:auto-ok` (standing consent) — the low-risk auto-advance path.** Only when **every** slice from Step 3 is **clear** (no ambiguous/needs-a-human slice). Then publish the children directly (Step 5) without async sign-off — they get `state:buildable` and still wait for a human's `state:agent-ready`, so the build gate is preserved. If **any** slice is ambiguous, **do not auto-advance** — fall through to parking below (auto-ok never forces an unclear breakdown through).

**No human present (batch without `state:auto-ok`, or the human defers) — the PRD is the surface.** Do **not** guess and publish. Post the proposed breakdown as a marked comment on the PRD for async review (template in [EXAMPLES.md](EXAMPLES.md)), then park the PRD by label and **skip it**:

```bash
gh issue edit <prd> --add-label "state:human-review-needed" --remove-label "state:slice-ready"
```

Removing `state:slice-ready` drops it from the batch queue; it returns only when a human replies and a later **interactive** run picks it up — Step 1 reads the newer replies, the interactive branch above swaps the label back, and slicing continues to Step 5.

## Step 5: Publish the child issues

Publish in **dependency order** (blockers first) so real issue numbers fill each "Blocked by". Each issue body follows the template in [EXAMPLES.md](EXAMPLES.md) — **Parent** (PRD + brief links), **What to build**, **Definition of Ready**, **Acceptance Criteria** (each tagged with the `US#` it proves, in EARS / Given-When-Then shape), **Implementation Map** (the Step 2 build map — proposed, component-level, `US#`-tagged; seeds the build, refreshed at build time), **Definition of Done** (all detailed checklists). Inherit `area:*` / `topic:*` from the PRD.

```bash
# clear slice — buildable, awaiting the human build gate
gh issue create --title "<slice title>" --body-file <body> \
  --label "type:task" --label "state:buildable"
# needs-a-human slice — has an open question to resolve first
gh issue create --title "<slice title>" --body-file <body> \
  --label "type:task" --label "state:human-review-needed"
```

Never apply `state:agent-ready` — that's the human's gate out (Step 7).

## Step 6: Link the PRD as the epic

Post the **durable epic record** — a marked comment listing the issues actually created (the permanent view of the slices; any Step 4 comment was only the pre-publish proposal). The PRD **stays open** as the tracking parent — the live reference until every child merges (unlike `create-prd`, which retires the brief). Then mark the PRD **`state:sliced`** and drop `state:slice-ready` — the swap records "this PRD is sliced" *and* drops it from the batch queue so it won't be re-sliced:

```bash
gh issue comment <prd> --body "> **🔪 slice-prd-agent**
> Sliced into child issues — this PRD stays open as the epic until they all merge.
> - [ ] #<a> <title>  (state:buildable)
> - [ ] #<b> <title>  (state:human-review-needed — needs your input)"
gh issue edit <prd> --add-label "state:sliced" --remove-label "state:slice-ready"
```

In **Notion** / **local KB**, add a "Sliced into <links>" line at the top of the PRD page/file and leave it open. Close the PRD only once all children are done.

## Step 7: Stop at the human gate

Report: the PRD (clickable link), the child issues created with their labels, which need human input and why, and the dependency order. (If instead the PRD was parked for async sign-off at Step 4, report that no issues were created and the breakdown awaits a reply on the PRD.) **Never apply `state:agent-ready`** — state plainly that a human must review each `state:buildable` issue and gate it before `implement-issue` picks it up, and resolve each `state:human-review-needed` issue first.

## Relationship to other skills

```
Raw idea → ideate → brief → create-prd → PRD (type:prd)
                                           │  human applies state:slice-ready  ← gate in
                                       slice-prd  ← this skill — PRD → child issues (type:task)
                                           │  human applies state:agent-ready  ← gate out (per child)
                                   implement-issue → PR → review-pr
```

- **create-prd** decides *what exactly* and writes the durable PRD.
- **slice-prd** decides *in what order, in what pieces* and writes the buildable tasks.
- **implement-issue** decides *how* and implements each task — only after a human gates it.
