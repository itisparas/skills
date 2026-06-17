---
name: ideate
description: Assess, classify, and route a raw human idea into a sharp, domain-consistent brief by interviewing the user one question at a time, in plain non-technical language (grill-style), until shared understanding, updating the domain docs inline as decisions land. Use when a user shares a raw idea, feature request, bug report, rough proposal, or asks how to proceed / what to build next / what to do about something — e.g. "ideate", "create a brief", "I was thinking…", "I have an idea", "should we build…", "what should we do about…", "how do we approach…", "next steps".
---

# Ideate

Assess, classify, and route a raw human idea into a sharp, domain-consistent brief. This is the front door for getting anything done — distinct from `build-from-issue`, which is the maintainer execution tool for implementation.

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

## Critical: `state:agent-ready` Label is Human-Only

The `state:agent-ready` label is a **human gate**. Ideate **never** applies this label. Ideate assesses and classifies — humans decide what gets built. This is a non-negotiable safety control.

## Agent Comment Marker

All comments posted by this skill **must** begin with the following marker line:

```
> **⚓️ ideate-agent**
```

This marker distinguishes ideate from human comments and from other skills (`🏗️ build-from-issue-agent`, `🔒 security-review-agent`, etc.).

## Running lean

Keep each conversation token-cheap and the context window small:

- **Load once.** Read `ORG_KB`, the glossary, and ADRs a single time in Step 1; work from a short in-memory summary. Don't re-read files you've already seen.
- **Search narrow.** Prefer targeted searches over reading whole files; pull only the lines you need. For **code**, use `ast-grep` (`sg`) for structural matches — never plain `grep` (see the `ast-grep` skill). Plain keyword search is only for **prose** (docs, briefs), which has no code AST to match.
- **Stable prefix.** Don't restate the loaded context every turn — reference it. A steady instruction prefix keeps prompt caching warm across the back-and-forth of the interview.
- **Terse internally.** Your own scratch reasoning and notes can be caveman-terse — drop articles and filler, fragments fine, `X -> Y` for cause. This **never** applies to what the user reads: questions to the user stay warm, plain, and complete (see Step 3).

## Invocation mode

This skill can be invoked directly by a human (providing a raw idea) or triggered by the model when a raw idea, feature request, or bug report surfaces in conversation. Either way, it interviews the user, then assesses, classifies, and routes the idea into a sharp, domain-consistent brief.

You'll follow the below steps upon invocation:

## Step 1: Context loading

Read the `ORG_KB` knowledge base and load it into memory — it holds the domain-specific information you'll use to assess and classify the idea. Also load the domain model you'll grill against in Step 3: the glossary (`CONTEXT.md`, or per-context `CONTEXT.md` files when a `CONTEXT-MAP.md` exists at the root) and the recorded decisions (ADRs under `docs/adr/` or in Notion).

## Step 2: Check for Existing Brief

Before interviewing the user, check whether any existing briefs are relevant to the idea, searching wherever this organisation keeps its docs (see Step 5). Search keywords and concepts related to the idea; if a relevant brief is found, reference it in your assessment and prefer appending to it (Step 5) over creating a duplicate.

- **GitHub** — `gh issue list --label "type:brief" --search "<idea keywords>" --repo <owner>/<repo>`
- **Notion** — search via the Notion MCP tool.
- **Local knowledge base** — keyword search the prose briefs under `$ORG_KB/` (e.g., `$ORG_KB/docs/briefs/`).

## Step 3: Interview the user

This is the core of ideate. Don't classify or write a brief from the raw idea alone — **interview the user relentlessly until you reach shared understanding**, walking down each branch of the decision tree and resolving dependencies one by one. The interview is what turns a fuzzy idea into a sharp, domain-consistent brief.

**Assume the user is non-technical.** This shapes every question you ask them:

- **Plain words only.** No jargon, acronyms, or code unless the user used them first. If you must name a technical thing, explain it in a few words with a quick analogy ("a cache is like keeping your most-used tool on the desk instead of back in the cupboard").
- **Use a live example.** Ground each question in a concrete scenario, not the abstract — not "what's the cancellation policy?" but "say someone cancels on Tuesday after paying on Monday — do they get their money back?"
- **One small idea per question.** If a question has two parts, split it and ask the more important part first.

Rules of the interview:

- **One question at a time.** Ask, wait for the answer, then ask the next. Never batch questions.
- **Always recommend an answer.** For each question, give your recommended answer and reasoning, so the user can simply confirm or correct.
- **Explore before asking.** If a question can be answered by reading the codebase, `ORG_KB`, or existing issues, go find the answer instead of asking the user.
- **Resolve dependencies in order.** Settle upstream decisions before the ones that depend on them.

Stay domain-aware throughout (the `grill-with-docs` half):

- **Challenge against the glossary.** When the user's word clashes with the agreed meaning in `CONTEXT.md`, say so plainly: "Earlier we settled that 'cancel' means the whole order stops — but just now it sounded like you meant pausing it. Which one?"
- **Sharpen fuzzy language.** When a word could mean two things, ask which: "You said 'account' — do you mean the person who pays, or the person who logs in? They can be different people."
- **Stress-test with concrete scenarios.** Walk through specific everyday examples that force the user to be precise about where one thing ends and another begins.
- **Cross-reference with code.** When the user says how something works today, quietly check the code agrees — use `ast-grep` (`sg`) for structural searches, never `grep` (see the `ast-grep` skill). If it doesn't agree, surface it in plain terms: "The system today refunds the full amount — but you just said partial refunds happen. Which is right?"

Update docs inline as decisions crystallise — don't batch them up:

- When a term is resolved, update `CONTEXT.md` right there (glossary only — no implementation details). If none exists, create it when the first term is resolved; in a multi-context repo, update the relevant context's `CONTEXT.md`.
- Offer an ADR only when all three hold: **hard to reverse**, **surprising without context**, and **the result of a real trade-off**. Otherwise skip it.

The interview ends when you and the user share a clear, unambiguous understanding of the problem and of what "done" looks like. Carry that into Step 4.

## Step 4: Classification

Classify the idea into exactly one category. You can reach a classification **during** the interview, not only after it: if the interview reveals the idea is a **duplicate** or **user-error**, you may short-circuit — but **confirm with the user before stopping or closing anything** ("This looks like a duplicate of #123 — close this and link it?"). Never close or stop silently. `bug-confirmed` and `feature-valid` always require the interview to reach shared understanding first.

The category determines the action and whether the idea proceeds to a brief.

| Classification    | Criteria                                                            | Action                                                                                                        |
| ----------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **bug-confirmed** | Agent diagnostics and codebase analysis confirm a real defect       | Apply relevant `area:*` / `topic:*` labels; assign the built-in **Bug** issue type. Proceed to Step 5.        |
| **feature-valid** | Design proposal is sound and feasible given the architecture        | Apply relevant `area:*` / `topic:*` labels; assign the built-in **Feature** issue type. Proceed to Step 5.    |
| **duplicate**     | An existing open issue or brief already covers this                  | Link the duplicate and close with a marker comment. Skip Steps 5–6.                                            |
| **user-error**    | The reported behaviour is expected, or it's a misconfiguration       | Comment with an explanation and guidance, then close. Skip Steps 5–6.                                          |
| **need-triage**   | Report appears valid but requires deeper analysis (triage candidate) | Apply the `need-triage` label and stop; leave for the triage flow. Skip Steps 5–6.                            |

Only **bug-confirmed** and **feature-valid** continue to routing and brief creation.

## Step 5: Route to the right doc store

Briefs live wherever this organisation keeps its docs. Determine the destination from how `ORG_KB` is configured, and route accordingly:

- **GitHub** — the brief is a GitHub issue labelled `type:brief` (default).
- **Notion** — create or update the brief page via the Notion MCP tool.
- **Local knowledge base** — write or update the brief under `$ORG_KB/` (e.g., `$ORG_KB/docs/briefs/`).

If Step 2 surfaced a relevant existing brief, **append to or refine that brief** rather than creating a duplicate. Otherwise create a new one.

## Step 6: Produce the brief

Write a **lean** brief — just enough for a human to decide whether to gate it. Leave the implementation approach to `build-from-issue`.

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

Post or update the brief in the destination chosen in Step 5. Every comment this skill posts begins with the `⚓️ ideate-agent` marker.

## Step 7: Stop at the human gate

Report what you did: the classification, the disposition (new brief / appended / closed as duplicate / user-error / labelled `need-triage`), and a link to the issue or page.

**Never apply `state:agent-ready`.** That label is the human gate (see above). End by stating explicitly that a human must review and gate the brief before anything is built.

