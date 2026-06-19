---
name: write-a-skill
description: Author a new agent skill for this organisation by interviewing the user one question at a time (ideate-style), placing it correctly among existing skills, and producing a SKILL.md that is token-lean, plain enough for non-technical readers, and consistent with organisational best practices. Use when a user wants to create, write, build, or scaffold a new skill — e.g. "write a skill", "create a skill", "I need a skill that…", "turn this into a skill", or invokes /write-a-skill.
---

# Write a Skill

Author a new agent skill for this organisation — the front door for *making* a skill. It interviews the user the way `ideate` does, then produces a `SKILL.md` that fits this org's conventions, costs few tokens to run, and reads plainly. Two layers run here: **how you (the author agent) work** (the `Running lean` and interview rules), and **the house contract** — the spec every skill you produce must satisfy. The contract is the point; don't ship a draft that breaks it.

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

- **Load once.** Read `ORG_KB`, the glossary, and the skills inventory once in Step 1; work from a short in-memory summary.
- **Search narrow.** Prefer targeted lookups over whole files. For **code** use `ast-grep` (`sg`), never `grep` (common patterns in the `ast-grep` skill's REFERENCE.md); keyword search is only for **prose**.
- **Stable prefix.** Reference loaded context rather than restating it, to keep prompt caching warm across the interview.
- **Terse internally, plain to the user.** Scratch notes can be caveman-terse (`X -> Y`; see `caveman`); what the user reads stays warm and complete (Step 4).

## The house contract

Every skill you produce must satisfy all of these — the acceptance criteria for the draft:

1. **Description with triggers.** Third person, ≤1024 chars. First sentence = what it does; then "Use when …" with concrete trigger phrases. It's the *only* thing the agent sees when deciding to load — make it discriminating. **YAML-safe:** the frontmatter is parsed by the installer (`npx skills`), and an unquoted scalar that contains `: ` (colon-space) or ` #` is invalid YAML — the parser errors and the skill is **silently skipped**. Use em-dashes or commas instead of mid-sentence colons (write `operations only — distilling`, not `operations only: distilling`), or wrap the whole value in quotes.
2. **A `Running lean` section.** Teach the skill's own agent to be token-efficient: load once, search narrow (`ast-grep` for code), progressive disclosure, sub-agents for big reads, stable prefix for cache warmth.
3. **Dual register, from `caveman`.** Internal scratch reasoning caveman-terse; everything the *user* reads plain, warm, complete. Never let terseness leak into user-facing text.
4. **Non-technical by default.** Plain words (no jargon unless the user used it first), any technical thing explained with a quick analogy, questions grounded in a **live worked example**. At least one concrete example in the skill.
5. **Org-aware.** Reads `ORG_KB`, respects the glossary (`CONTEXT.md`) and ADRs, doesn't duplicate an existing skill. If it posts comments/artefacts it carries a distinct marker (e.g. `> **🛠️ <skill>-agent**`) — pick one not already in the README "Comment markers" table and record it there.
6. **Routes through labels and markers — never prose.** Every branch, hand-off, and request for human attention is decided by a **label**: pick up work because an issue carries one, advance by swapping labels, ask for a human by applying one. Human decision points are always **human-only labels** the skill reads but never applies (mirroring `state:agent-ready` / `state:prd-ready`). Reuse a label from the README "Labels" table where one fits; only mint a new one when routing genuinely isn't covered, and register it. State which labels it reads, sets, and treats as human-only.
7. **Progressive disclosure.** SKILL.md stays ~under 150 lines. Push detailed reference, long examples, or rarely-needed material into sibling files (`REFERENCE.md`, `EXAMPLES.md`) one level deep. Deterministic work goes in `scripts/`, not regenerated prose.
8. **No time-sensitive info, consistent terminology.** No "as of today"; convert relative dates to absolute. One name per concept.

## Step 1: Context loading

Read the `ORG_KB` knowledge base and the domain model you'll grill against: the glossary (`CONTEXT.md`, or per-context files when a `CONTEXT-MAP.md` exists) and recorded decisions (ADRs under `docs/adr/` or Notion). Then **inventory the existing skills** so the new one fits and doesn't duplicate — look in `$ORG_KB/.agents/skills/`, a repo `skills/` dir, and `~/.claude/skills/`. Read only each `name` + `description` frontmatter (cheap), not whole bodies. Hold a short list in memory: what exists and the conventions they share (markers, `Running lean`, ORG_KB usage, human-gate labels).

## Step 2: Check for an overlapping skill

Search the inventory and docs (skill descriptions, briefs in Notion / `$ORG_KB`) for the idea's keywords. If something overlaps, surface it plainly and prefer **extending the existing skill** over a near-duplicate — confirm the direction with the user before proceeding.

## Step 3: Place the skill — what kind is it?

Settle **where this skill sits** before interviewing on details — it decides the name, triggers, hand-offs, and inherited conventions. Ask directly, recommending the placement you think fits and why:

| Placement | Directory (this repo) | What it means | Inherits |
| --- | --- | --- | --- |
| **Independent / utility** | `skills/utility/` | Standalone capability, no pipeline ties (formatter, lookup) | `Running lean`, dual register |
| **Engineering / build workflow** | `skills/engineering/` | A stage in the build pipeline (`ideate` → … → `review-pr`) | Pipeline handoffs, agent marker, human-gate awareness |
| **Productivity** | `skills/productivity/` | Speeds a human/agent routine (triage, summaries, scaffolding) | Org-KB awareness, lean batch handling |
| **Communication / style mode** | `skills/communication/` | Changes *how* the agent talks, not what it does (like `caveman`) | Persistence rules, auto-clarity exceptions |
| **Domain / knowledge** | `skills/domain/` | Encodes org-specific subject expertise from `ORG_KB` | Glossary alignment, references one level deep |

The placement decides the **category directory**. If it spans two, pick the primary and note the secondary in the triggers. Don't move on until placement is agreed.

The directory above applies when authoring **in this skills repo**. When you run inside a **live target project** (skills already installed there via `npx skills`), follow that project's runner convention instead — write the skill flat under `.agents/skills/<name>/` (or the harness's skills dir) and symlink into the harness-specific locations, rather than the category layout.

## Step 4: Interview the user (ideate-style)

The core. Don't draft from the raw request — **interview the user regressively until shared understanding**, walking each branch and resolving dependencies one by one, circling back to sharpen earlier answers. **Assume the user is non-technical:**

- **Plain words only.** No jargon/code unless the user used it first; explain any technical thing with a quick analogy ("a trigger is like the phrase that wakes a voice assistant").
- **Use a live example.** Ground each question in a concrete scenario — not "what are the inputs?" but "say a teammate types *write a skill that checks our API docs are up to date* — what would it look at first?"
- **One small idea per question.** Ask, wait, ask the next. Never batch.
- **Always recommend an answer** with reasoning. **Explore before asking** (codebase/`ORG_KB`/existing skills may already answer it). **Resolve dependencies upstream-first.**

Cover by the end (one question at a time, not as a list): **Trigger** (exact phrases/contexts); **Inputs** (files, issue, diff, text); **Steps** (including any **deterministic** sub-step that should become a `scripts/` helper); **Outputs** (artefact + where it lands); **Relationships** (calls / is called by / must not overlap); **Failure modes & gates** (what it refuses; any human-only label it never auto-applies); **What "good" looks like** (the observable bar). Ends when you both share a clear picture of trigger, behaviour, and "done".

## Step 5: Draft the skill

Create the directory and write `SKILL.md` from the template, satisfying every contract point. Add `REFERENCE.md`/`EXAMPLES.md`/`scripts/` only when the contract calls for it.

```
skills/<category>/skill-name/      # <category> from Step 3; flat .agents/skills/skill-name/ in a live project
├── SKILL.md          # required
├── REFERENCE.md      # only if SKILL.md would exceed ~150 lines
├── EXAMPLES.md       # only if examples are long
└── scripts/          # only for deterministic operations
```

```md
---
name: skill-name
description: <what it does>. Use when <concrete trigger phrases/contexts>.
---

# Skill Name

<one-paragraph framing: what front door this is, how it relates to sibling skills>

## Prerequisites
<ORG_KB / gh / Notion as applicable>

## Running lean
<load once · search narrow (ast-grep for code) · progressive disclosure · terse internal, plain to user>

## Steps
<numbered procedure. Interview-style where a human is present; one question at a time, recommend answers, ground in a live example with an analogy.>

## <Output / marker / human gate>
<the artefact it produces; agent marker; any human-only gate it must never cross>
```

## Step 6: Review with the user

Present the draft and confirm coverage against the agreed trigger, steps, and outputs. On any gap, regress through the relevant Step 4 branch rather than patching blindly.

## Step 7: Validate against the contract

Before declaring done, check every box:

- [ ] Description third person, ≤1024 chars, with concrete "Use when …" triggers
- [ ] Frontmatter is valid YAML — no `: ` (colon-space) or ` #` inside an unquoted `description`/`name`, else `npx skills` silently skips the skill (verify it loads after install)
- [ ] `Running lean` present and specific (ast-grep for code, progressive disclosure, sub-agents for big reads)
- [ ] Dual register honoured — terse internal, plain/warm user-facing
- [ ] Plain language, at least one analogy and one live worked example
- [ ] Org-aware: reads `ORG_KB`, respects glossary/ADRs, distinct marker if it posts; no duplicate
- [ ] Routes every branch / hand-off / human-attention call through labels (not prose); human gates are human-only; labels reused where possible, any new one registered in the README "Labels" table
- [ ] SKILL.md ≤ ~150 lines; references one level deep; deterministic work in `scripts/`
- [ ] No time-sensitive info; consistent terminology
- [ ] Relationship to sibling skills stated; any human gate explicit and never auto-crossed

Report what you built: the placement (Step 3), trigger, artefacts, relationship to existing skills, and the path to the new `SKILL.md`.
