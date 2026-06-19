---
name: ideate
description: Assess, classify, and route a raw human idea into a sharp, domain-consistent brief by interviewing the user one question at a time, in plain non-technical language (grill-style), until shared understanding, updating the domain docs inline as decisions land. Use when a user shares a raw idea, feature request, bug report, rough proposal, or asks how to proceed / what to build next / what to do about something — e.g. "ideate", "create a brief", "I was thinking…", "I have an idea", "should we build…", "what should we do about…", "how do we approach…", "next steps".
---

# Ideate

Assess, classify, and route a raw human idea into a sharp, domain-consistent brief. This is the front door for getting anything done — distinct from `implement-issue`, the maintainer execution tool. Invoked directly by a human or triggered when a raw idea / feature request / bug report surfaces in conversation; either way it interviews, then assesses, classifies, and routes.

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

## Critical: `state:agent-ready` is human-only

`state:agent-ready` is a **human gate**. Ideate **never** applies it — it assesses and classifies; humans decide what gets built. Non-negotiable.

## Agent Comment Marker

All comments **must** begin with `> **⚓️ ideate-agent**` — distinguishing ideate from humans and other skills (`👷 implement-issue-agent`, `🔒 security-review-agent`).

## Running lean

- **Load once.** Read `ORG_KB`, glossary, and ADRs once in Step 1; work from a short summary.
- **Context budget (≤150k, soft).** Hold summaries, not raw file dumps; spawn a sub-agent for any heavy codebase read rather than loading it inline.
- **Search narrow.** Pull only the lines you need. For **code** use `ast-grep` (`sg`), never `grep` (common patterns in the `ast-grep` skill's REFERENCE.md); keyword search is only for **prose**.
- **Stable prefix.** Reference loaded context rather than restating it, to keep prompt caching warm across the interview.
- **Terse internally.** Scratch reasoning can be caveman-terse (`X -> Y`); this **never** touches what the user reads — questions stay warm, plain, complete (Step 3).

## Step 1: Context loading

Read the `ORG_KB` knowledge base into memory — the domain info you'll use to assess and classify. Also load the domain model for Step 3: the glossary (`CONTEXT.md`, or per-context files when a root `CONTEXT-MAP.md` exists) and recorded decisions (ADRs under `docs/adr/` or Notion).

## Step 2: Check for an existing brief

Before interviewing, search wherever the org keeps docs (see Step 5) for briefs relevant to the idea. If one is found, reference it in your assessment and prefer appending (Step 5) over duplicating.

- **GitHub** — `gh issue list --label "type:brief" --search "<idea keywords>" --repo <owner>/<repo>`
- **Notion** — search via the Notion MCP tool.
- **Local KB** — keyword search briefs under `$ORG_KB/` (e.g. `$ORG_KB/docs/briefs/`).

## Step 3: Interview the user

The core. Don't classify or write from the raw idea alone — **interview relentlessly until shared understanding**, walking each branch and resolving dependencies one by one. **Assume the user is non-technical:**

- **Plain words only.** No jargon/code unless the user used it first; explain any technical thing with a quick analogy ("a cache is like keeping your most-used tool on the desk, not back in the cupboard").
- **Use a live example.** Ground each question concretely — not "what's the cancellation policy?" but "say someone cancels Tuesday after paying Monday — do they get their money back?"
- **One small idea per question;** split two-part questions, ask the more important part first.
- **One question at a time** (ask, wait, ask the next — never batch). **Always recommend an answer** with reasoning. **Explore before asking** (codebase/`ORG_KB`/issues may answer it). **Resolve dependencies upstream-first.**

Stay domain-aware (the `grill-with-docs` half):

- **Challenge against the glossary.** When the user's word clashes with `CONTEXT.md`, say so: "Earlier 'cancel' meant the whole order stops — just now it sounded like pausing. Which?"
- **Sharpen fuzzy language.** "You said 'account' — the person who pays, or who logs in? They can differ."
- **Stress-test with concrete scenarios** that force precision about where one thing ends and another begins.
- **Cross-reference with code** (via `ast-grep`, not `grep`). If it disagrees with the user, surface it plainly: "The code refunds the full amount today, but you said partial refunds happen — which is right?"

Update docs inline as decisions crystallise (don't batch): when a term resolves, update `CONTEXT.md` right there (glossary only, no implementation detail; create it on the first term if absent; in multi-context repos update the relevant one). Offer an ADR only when all three hold — **hard to reverse**, **surprising without context**, **the result of a real trade-off**; otherwise skip. The interview ends when you and the user share an unambiguous understanding of the problem and of "done".

## Step 4: Classification

Classify into exactly one category — reachable **during** the interview, not only after. If the interview reveals a **duplicate** or **user-error** you may short-circuit, but **confirm before stopping or closing anything** ("Looks like a duplicate of #123 — close and link?"); never close silently. `bug-confirmed` and `feature-valid` always require the interview to reach shared understanding first.

| Classification | Criteria | Action |
| --- | --- | --- |
| **bug-confirmed** | Diagnostics confirm a real defect | Apply `area:*`/`topic:*`; assign built-in **Bug** type. Proceed to Step 5. |
| **feature-valid** | Design proposal sound and feasible | Apply `area:*`/`topic:*`; assign built-in **Feature** type. Proceed to Step 5. |
| **duplicate** | An existing issue/brief already covers this | Link the duplicate, close with a marker comment. Skip Steps 5–6. |
| **user-error** | Behaviour is expected, or a misconfiguration | Comment explanation + guidance, then close. Skip Steps 5–6. |
| **needs-triage** | Appears valid but needs deeper analysis before it can be a brief | Apply `state:human-review-needed` and leave the issue **untyped** (no `type:brief`) with a marker comment; a human triages it. Skip Steps 5–6. |

Only **bug-confirmed** and **feature-valid** continue to routing and brief creation.

## Step 5: Route to the right doc store

Determine the destination from how `ORG_KB` is configured:

- **GitHub** — a GitHub issue labelled `type:brief` (default).
- **Notion** — create/update the brief page via the Notion MCP tool.
- **Local KB** — write/update under `$ORG_KB/` (e.g. `$ORG_KB/docs/briefs/`).

If Step 2 surfaced a relevant brief, **append to or refine it** rather than duplicating.

## Step 6: Produce the brief

Write a **lean** brief — just enough for a human to decide whether to gate it. Leave the implementation approach to `implement-issue`.

```markdown
> **⚓️ ideate-agent**

## Problem
<one or two sentences — what's wrong or missing, and why it matters>

## Acceptance criteria
- <observable, checkable outcome>
- <…>

## Open questions
- <anything still genuinely unresolved after the interview — should be rare>
```

Post or update the brief in the Step 5 destination, beginning with the marker.

## Step 7: Stop at the human gate

Report: the classification, the disposition (new brief / appended / closed as duplicate / user-error / parked for triage with `state:human-review-needed`), and a link. **Never apply `state:agent-ready`** — end by stating that a human must review and gate the brief before anything is built. For a low-risk brief, note the option: a human may apply **`state:auto-ok`** to let `create-prd` → `slice-prd` carry it through the cheap gates automatically (the build gate still stays human-only) — without it, each stage waits for its normal `state:prd-ready` / `state:slice-ready` gate.
