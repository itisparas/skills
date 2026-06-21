# skills

A collection of [agent skills](https://docs.anthropic.com/en/docs/claude-code/skills) for an **idea-to-merge workflow** built around an organisation knowledge base, GitHub issues/PRs, and Notion. Each skill is a self-contained `SKILL.md` (plus any bundled references) that an agent loads on demand.

The skills are designed to chain: an idea is interviewed into a brief, specced into a PRD, sliced into buildable tasks, built, and reviewed — with a human gating each major step and GitHub **labels** carrying state between them.

## Skills in this repo

Skills live under a category directory (`skills/<category>/<name>/`): **engineering** (the idea-to-merge build pipeline), **utility** (standalone tools), and **productivity** (routines that speed a human or agent up).

| Skill | Category | Role | Output |
| --- | --- | --- | --- |
| [`ideate`](skills/engineering/ideate/SKILL.md) | engineering | **Front door.** Interviews the user one question at a time in plain, non-technical language (grill-style), sharpening domain terms and updating `CONTEXT.md`/ADRs inline. Then classifies and routes the idea. | A lean `type:brief` issue (or an append / close / triage) |
| [`create-prd`](skills/engineering/create-prd/SKILL.md) | engineering | **Spec writer.** Takes an issue number or auto-searches `type:brief` + `state:prd-ready` briefs, investigates the codebase in a sub-agent, and publishes a durable PRD as a **new** artifact in the brief's store — then retires the brief (closed/archived, cross-linked). Open questions become a marked comment + `state:human-review-needed` on the brief. Sits between `ideate` and `implement-issue`. | A `type:prd` issue/page (problem, user stories, decisions, seams) |
| [`slice-prd`](skills/engineering/slice-prd/SKILL.md) | engineering | **Work slicer.** Takes a `type:prd` issue number or auto-searches `type:prd` + `state:slice-ready` PRDs, investigates the codebase in a sub-agent, then interviews the user to set granularity and breaks the PRD into **tracer-bullet** child issues (each cutting through every layer). Clear slices get `state:buildable`; ambiguous ones get `state:human-review-needed`. The PRD is marked `state:sliced` and stays open as an epic. Sits between `create-prd` and `implement-issue`. | `type:task` child issues with Ready/Acceptance/Done checklists, linked to the PRD + brief |
| [`implement-issue`](skills/engineering/implement-issue/SKILL.md) | engineering | **Implementer.** Takes a `type:task` number (or auto-searches `type:task` + `state:agent-ready`), claims each with `state:building`, builds it **test-first** on a feature branch, and opens a PR (labelled `state:review-ready`) that closes the issue. On a later run — issue already marked, or given a PR — it reads `review-pr`'s findings and **reworks** the PR to address them, then hands back for re-review. Parks what it can't finish (`state:blocked` / `state:human-review-needed`). Loops with `review-pr` until merge-ready. | A feature-branch PR, built and reworked to merge-ready |
| [`review-pr`](skills/engineering/review-pr/SKILL.md) | engineering | **Gatekeeper.** Reviews a diff (or a `state:review-ready` PR) on two independent axes — **Standards** and **Spec** — using parallel sub-agents, **aligns each finding's disposition with the user interview-style**, then — when a fix is agreed — has an `implement-issue` sub-agent (spawned via the `Agent` tool) make it **inline**, posts the marked comment, and **merges and closes the PR itself**. Never edits code directly; only an unresolved judgement call is handed to a human by label. | A side-by-side report + agreed PR comment, and a merged-and-closed PR |
| [`write-a-skill`](skills/productivity/write-a-skill/SKILL.md) | productivity | **Skill smith.** Interviews the user one question at a time (ideate-style), places the new skill among the existing ones, and drafts a `SKILL.md` against a house contract — token-lean, plainly worded, caveman-terse internally. | A new org-style `SKILL.md` (plus refs/scripts if needed) |
| [`knowledge-base`](skills/productivity/knowledge-base/SKILL.md) | productivity | **KB bootstrapper & caretaker.** Interviews the user to pick a backend (GitHub, Notion, local, or hybrid), records the choice, scaffolds the full idea-to-merge structure (pipeline labels / databases / numbered folders + AGENTS.md), installs a detect-and-offer hook, and stays on as owner of the *structure*. The thing that builds the `ORG_KB` every other skill assumes. | A live knowledge base + `kb-config.yml` |
| [`instincts`](skills/productivity/instincts/SKILL.md) | productivity | **Preference keeper.** Owns portable coding preferences ("instincts") as hand-editable markdown rules in a project-tier `.instincts/` folder and a user-tier `~/.instincts/` repo. Handles the heavy ops — distil from a codebase, bootstrap the user repo, push/pull, promote/demote, regenerate the `AGENTS.md` index — while the everyday apply loop runs off that index with no invocation. `knowledge-base` scaffolds the folder and wires the block. | `.instincts/` rule files + an always-on `AGENTS.md` index |
| [`ast-grep`](skills/utility/ast-grep/SKILL.md) | utility | **Shared tool.** Structural code search with [ast-grep](https://ast-grep.github.io/). The other skills use `ast-grep` (`sg`) for **all code search** in place of `grep`; the [REFERENCE.md](skills/utility/ast-grep/REFERENCE.md) cheat sheet is loaded only when building a non-trivial rule. | — (referenced by the others) |

> `security-review` is referenced by the workflow below but is **not** part of this repo — it's a sibling tool in the broader pipeline.

## Reusable agents

The pipeline skills hand their heavy reads and reviews to **shared sub-agent personas** that live in [`agents/`](agents/) — extracted once, carrying `model`/`tools` frontmatter, instead of re-written inline per skill. This is the main cost lever: the mechanical read-and-summarise jobs run on cheap, fast models with read-only tools; only code-writing stays on the strong model.

| Agent | Model | Used by | Role |
| --- | --- | --- | --- |
| [`kb-investigator`](agents/kb-investigator.md) | Haiku | create-prd, slice-prd, implement-issue | Read-only codebase mapper — feasibility / slicing seams / build map. Returns a short decisions-and-prose map (≤500 words) + a Low/Med/High feasibility rating. Path-free for the durable purposes (feasibility/slicing); the **build map** purpose may return file:line targets (ephemeral, consumed in-session) so the implementer doesn't re-explore. |
| [`standards-reviewer`](agents/standards-reviewer.md) | Sonnet | review-pr | Read-only Standards axis — checks the diff against documented standards **and the project `.instincts/` rules**. ≤400 words. |
| [`spec-reviewer`](agents/spec-reviewer.md) | Sonnet | review-pr | Read-only Spec axis — checks the diff against the originating issue/PRD/ADR. ≤400 words. |

**Tiering rule:** reads and reviews go to a cheap model; **anything that writes code (the `implement-issue` build, and review-pr's inline fixer) stays on the strong model.** `npx skills` does **not** install agents — see Installation.

## The workflow

```mermaid
flowchart LR
    idea([Raw idea]) --> ideate

    subgraph ideate["🦫 ideate"]
        interview[Interview the user] --> classify[Classify] --> brief[Write lean brief]
    end

    brief --> briefgate{{"Human applies<br/>state:prd-ready"}}
    briefgate -->|gated| createprd

    subgraph createprd["📐 create-prd"]
        investigate[Investigate codebase] --> seams[Resolve open questions] --> prd[Write durable PRD]
    end

    seams -. open questions .-> attention[/state:human-review-needed/]
    attention -. ideate-style interview .-> briefgate
    prd --> slicegate{{"Human applies<br/>state:slice-ready"}}
    slicegate -->|gated| sliceprd

    subgraph sliceprd["🔪 slice-prd"]
        slices[Draft tracer-bullet slices] --> coarseness[Set coarseness w/ user] --> children[Publish child issues]
    end

    children --> gate{{"Human applies<br/>state:agent-ready<br/>(per child)"}}
    children -. ambiguous slice .-> attention
    gate -->|gated| build

    subgraph build["👷 implement-issue"]
        claim[Claim w/ state:building] --> tdd[TDD red-green-refactor] --> openpr[Open PR]
    end

    build -. blocked .-> blocked
    build -. needs judgement .-> attention
    openpr --> pr([Pull request])
    pr --> reviewgate{{"build labels PR<br/>state:review-ready"}}
    reviewgate -->|triggers| review

    subgraph review["🔎 review-pr"]
        standards[Standards axis] & spec[Spec axis]
    end

    review -. align findings w/ user .-> review
    review -->|fix agreed| fix[implement-issue sub-agent<br/>fixes inline]
    fix -. re-check .-> review
    review -->|clean + confirm| merged([review-pr merges & closes])
    review -. blocked by branch protection .-> ready[/state:merge-ready/]
    ready -. human merges .-> merged
    review -->|needs a human| human[/state:human-review-needed/]
```

1. **Ideate.** A raw idea enters through `ideate`. It interviews the user until there's shared understanding, classifies the idea, and — for valid bugs/features — writes a **lean brief** (`type:brief` issue). Glossary terms and ADRs are updated inline as decisions land. Duplicates and user-errors are closed (with confirmation); valid-but-unshaped ideas are parked **untyped** with `state:human-review-needed` for a human to triage.
2. **Spec.** A human gates a brief for speccing with **`state:prd-ready`**. `create-prd` then picks it up — by issue number (`create prd 250`) or by auto-searching `type:brief` + `state:prd-ready` in batch — investigates the codebase in a sub-agent, and writes a **durable PRD** (`type:prd` issue) of *decisions* rather than file paths, which rot. The PRD is a **new** artifact in the brief's own store; once it's posted, the brief is **retired** — closed (GitHub) / archived (Notion) / moved to an archive folder (local KB), cross-linked both ways — so the pipeline carries exactly one live artifact. If a blocking question surfaces it never guesses: with a human present it resolves it through an **`ideate`-style interview** (one question at a time, recommending answers, updating the brief inline) that carries the brief to `state:prd-ready`; in batch with no human, it parks the brief with a marked comment + **`state:human-review-needed`** (swapping off `state:prd-ready`) for that interview to happen later. It **never** applies `state:agent-ready`.
3. **Slice gate + slicing.** A human reviews the PRD and applies **`state:slice-ready`** (a human-only gate). `slice-prd` then picks it up — by number (`slice prd 250`) or by auto-searching `type:prd` + `state:slice-ready` in batch — investigates the codebase in a sub-agent, interviews the user to set granularity, and breaks the PRD into **tracer-bullet** `type:task` child issues (each a thin vertical slice through every layer, with detailed Definition of Ready / Acceptance Criteria / Definition of Done). Clear, buildable slices get **`state:buildable`**; ambiguous ones get **`state:human-review-needed`**. The PRD itself is marked **`state:sliced`** (off `state:slice-ready`) and **stays open as the epic** until its children merge — so a sliced PRD is distinguishable by label from one still awaiting its gate. It **never** applies `state:agent-ready`.
4. **Human gate.** A human reviews each `state:buildable` child issue and applies **`state:agent-ready`**. This label is a deliberate human-only gate — **agents never apply it.** Nothing gets built until a person says so.
5. **Build.** `implement-issue` picks up gated issues — by number (`implement 250`) or by auto-searching `type:task` + `state:agent-ready` in batch — **claims** each by swapping `state:agent-ready` → `state:building` (so nothing double-picks it), then builds it **test-first** (red-green-refactor through the issue's Acceptance Criteria) on a feature branch and opens a PR that closes the issue. It hands off to review **by label** — it tags the PR **`state:review-ready`** rather than calling `review-pr` directly, and drops its own marker comment on the issue so a later run knows a PR exists. A build it can't finish is parked: `state:blocked` for a hard technical failure, `state:human-review-needed` for one needing a person's judgement — and a human re-applies `state:agent-ready` to authorise a retry. It **never** applies `state:agent-ready` itself.
6. **Review.** `review-pr` picks up PRs carrying **`state:review-ready`** (or a fixed point a user names) and reviews the diff on two axes that can pass/fail independently — **Standards** (does it follow documented coding standards?) and **Spec** (does it implement what the issue/PRD/ADR asked for?). It does **not** auto-post: it **aligns each finding's disposition with the user interview-style** (one question at a time, recommending an answer). For any finding agreed as a **code fix**, it doesn't label-and-wait — it spawns an **`implement-issue` sub-agent via the `Agent` tool** to make the fix **inline** (test-first, pushed) and re-checks, looping until clean. Then it posts the agreed `🔎 review-pr-agent` comment, consumes `state:review-ready`, and — since landing the PR is **its** responsibility — **merges and closes the PR itself** (confirming once first; `--auto` when checks are pending). The only outcome handed to a human is a disposition that genuinely needs human judgement (`state:human-review-needed`); branch protection requiring another approver is the sole case where it leaves `state:merge-ready` for a human.
7. **Inline fix loop.** The review→fix→re-check loop happens **within a single `review-pr` run**: each agreed fix is made by an `implement-issue` sub-agent and re-reviewed on the new diff before the comment is posted, so the PR is already clean by the time review-pr merges it. (The older async loop — `implement-issue` picking up a `state:blocked` PR on a separate run — still applies when a build is parked mid-stream, not as the review hand-off.)

## Installation

These skills install with [`npx skills`](https://github.com/vercel-labs/skills) (the open agent-skills CLI; works with Claude Code, Codex, Cursor, and others). It auto-detects which agents you have installed.

```bash
# Install everything from this repo
npx skills add itisparas/skills

# See what's available first
npx skills add itisparas/skills --list

# Install a single skill
npx skills add itisparas/skills --skill ideate

# Install for all your agents, no prompts, copy instead of symlink
npx skills add itisparas/skills --all -y --copy

# Global install (user directory) instead of per-project
npx skills add itisparas/skills -g
```

**Agents are a separate step.** `npx skills` installs `SKILL.md` folders only — it does **not** install the reusable agents (`.claude/agents/*.md`). After adding the skills, install the agents so skills can spawn them by name:

```bash
scripts/install-agents.sh         # per-project  -> .claude/agents/
scripts/install-agents.sh -g      # global       -> ~/.claude/agents/
```

On harnesses without named subagents the skills fall back to a `general-purpose` sub-agent on a fast model that follows the matching `agents/*.md` file — so the workflow still runs, with model tiering degraded to advisory.

<details>
<summary>Manual install (symlink)</summary>

```bash
# Claude Code — per project
ln -s "$PWD/skills/engineering/ideate"        .claude/skills/ideate
ln -s "$PWD/skills/engineering/create-prd"    .claude/skills/create-prd
ln -s "$PWD/skills/engineering/slice-prd"     .claude/skills/slice-prd
ln -s "$PWD/skills/engineering/implement-issue" .claude/skills/implement-issue
ln -s "$PWD/skills/engineering/review-pr"     .claude/skills/review-pr
ln -s "$PWD/skills/productivity/write-a-skill" .claude/skills/write-a-skill
ln -s "$PWD/skills/productivity/knowledge-base" .claude/skills/knowledge-base
ln -s "$PWD/skills/productivity/instincts"     .claude/skills/instincts
ln -s "$PWD/skills/utility/ast-grep"          .claude/skills/ast-grep

# …or globally
ln -s "$PWD/skills/engineering/ideate"    ~/.claude/skills/ideate

# Agents (separate from skills) — or just run scripts/install-agents.sh
ln -s "$PWD/agents/kb-investigator.md"    .claude/agents/kb-investigator.md
ln -s "$PWD/agents/standards-reviewer.md" .claude/agents/standards-reviewer.md
ln -s "$PWD/agents/spec-reviewer.md"      .claude/agents/spec-reviewer.md
```

For Codex CLI and other runners, place the skill folders under that tool's skills directory (commonly `.agents/skills/`).
</details>

## Requirements

- **[ast-grep](https://ast-grep.github.io/)** (`sg`) — `brew install ast-grep`. Used for all code search.
- **`gh` CLI**, authenticated (`gh auth status`) — issues, labels, PR comments.
- **Notion MCP** configured for your organisation — see the setup block in each skill's prerequisites.
- **`ORG_KB`** environment variable pointing at the organisation knowledge base (e.g. `export ORG_KB=./`).

## Labels

**Every branch, route, and hand-off in this workflow is decided by a label, and every agent comment is stamped with a marker — nothing is inferred from prose.** A skill picks up work because an issue carries a label, advances it by swapping labels, and asks for a human by applying one. Human decision points are *always* a human-only label (`state:prd-ready`, `state:slice-ready`, `state:agent-ready`) that agents read but never apply. This is what keeps the pipeline auditable and the human gates real: the label *is* the contract, and these tables are its single source of truth. One **opt-in** label, `state:auto-ok`, lets a human grant *standing* consent so a low-risk item self-advances through the **cheap** gates — but it's still a human who applied it (auditable), the agents stop the moment risk appears, and the **build gate (`state:agent-ready`) stays strictly human**.

### Label lifecycle

Labels are how work moves down the pipeline. A piece of work changes *type* as it's refined (`brief` → `prd` → `task`) and pauses at a *human gate* between each stage — a `state:*` label only a person applies. Reading top to bottom is the full journey of one idea:

| Stage | The live issue carries | Set by | To advance, a human applies | Picked up by |
| --- | --- | --- | --- | --- |
| **Idea → brief** | `type:brief` (+ `Bug`/`Feature`, `area:*`/`topic:*`) | `ideate` | `state:prd-ready` | `create-prd` |
| **Brief → PRD** | `type:prd` (the brief is retired/closed) | `create-prd` | `state:slice-ready` | `slice-prd` |
| **PRD → tasks** | `type:task` + `state:buildable`, one per slice (the PRD, now `state:sliced`, stays open as the epic) | `slice-prd` | `state:agent-ready` (per task) | `implement-issue` |
| **Task → build** | `type:task` + `state:building` (claimed; `state:agent-ready` removed) | `implement-issue` | — (the agent builds it now) | `implement-issue` |
| **Build → PR** | the PR carries `state:review-ready` (and closes its task issue) | `implement-issue` | — (the label triggers review) | `review-pr` |
| **Review** | agreed fixes are made **inline** by an `implement-issue` sub-agent (spawned via the `Agent` tool), then `review-pr` **merges and closes** the PR; a `state:human-review-needed` label is applied only for a disposition needing human judgement | `review-pr` (after aligning findings with the user, and fixing inline) | — (review-pr lands it) | `review-pr` / humans |
| **PR → merge** | merged and closed by `review-pr` itself; `state:merge-ready` for a human only when branch protection requires another approver | `review-pr` | merge (review-pr's own responsibility) | `review-pr` / humans |

**Detours off the happy path:** when a skill needs a person's judgement mid-stream — `create-prd` hits a blocking open question, or `slice-prd` produces an ambiguous slice — it applies **`state:human-review-needed`** (swapping off the gate label so batch mode skips it) and parks the issue until a human resolves it. `ideate` uses the **same** label for a valid idea that needs deeper analysis before it can become a brief — left **untyped**, so an untyped `state:human-review-needed` issue is the triage signal (vs a typed one, which is a parked in-flight artifact).

### Label reference

State flows through GitHub labels rather than through any shared database. The skills read and write these:

| Label | Meaning | Set by | Read by |
| --- | --- | --- | --- |
| `type:brief` | The issue is a brief produced by ideate | `ideate` | `ideate` (dedup), humans |
| `state:prd-ready` | **Human gate** — a brief is approved to be specced into a PRD. Agents **never** apply this. | Human only | `create-prd` (batch search) |
| `type:prd` | The issue is a PRD expanded from a brief | `create-prd` | `create-prd` (dedup), humans, `slice-prd` |
| `state:slice-ready` | **Human gate** — a PRD is approved to be sliced into tasks. Agents **never** apply this. | Human only | `slice-prd` (batch search) |
| `state:sliced` | A **PRD** has been sliced into child tasks and is now the open epic tracking them. Applied off `state:slice-ready`; tells a sliced PRD apart from one still awaiting its gate, and keeps batch mode from re-slicing. Removed when the PRD closes (all children merged). | `slice-prd` | `slice-prd` (skip re-slice), humans |
| `type:task` | The issue is a buildable child task sliced from a PRD | `slice-prd` | humans, `implement-issue` |
| `state:buildable` | A child task is clear and buildable, awaiting the human build gate. Not itself a build gate. | `slice-prd` | humans |
| `state:agent-ready` | **Human gate** — approved to build. Agents **never** apply this. | Human only | `implement-issue` (batch search) |
| `state:auto-ok` | **Standing human consent** for low-risk auto-advance. A human applies it once on a brief/PRD; the chain then carries a *low-risk* item through the **cheap** gates (`prd-ready`, `slice-ready`) without per-step clicks. `create-prd`/`slice-prd` honour it **only** when the work is low-risk (feasibility Low / no ambiguous slice), else they park `state:human-review-needed`. `create-prd` propagates it brief → PRD. It is **not** a gate and **never** substitutes for `state:agent-ready` — the build gate stays human-only. | Human applies; `create-prd` propagates | `create-prd`, `slice-prd` (batch search) |
| `state:building` | A task is being actively built — claims it and drops it from the batch queue. Removed when it parks; retired with the issue when its PR closes it. | `implement-issue` | `implement-issue`, humans |
| `state:review-ready` | A **PR** is built (or reworked) and awaiting review — the hand-off from build to review. Set on first PR and after each rework round; consumed (removed) by `review-pr` when it posts its outcome. | `implement-issue` | `review-pr` (batch search), humans |
| `state:blocked` | A build can't finish and is parked mid-stream for a human to authorise a retry. (Review no longer emits this — `review-pr` fixes agreed changes inline via an `implement-issue` sub-agent rather than handing off by label.) | `implement-issue` | humans |
| `state:merge-ready` | Both review axes are clean but `review-pr` couldn't auto-merge (checks pending, branch protection, conflicts, or no human to confirm) — a human merges. On a clean pass that *can* merge, `review-pr` merges directly and skips this label. | `review-pr` | humans |
| `state:human-review-needed` | Findings, open questions, a raw idea needing triage, or a build needing judgement need human judgement (untyped issue = the `ideate` triage case) | `ideate`, `review-pr`, `create-prd`, `slice-prd`, `implement-issue` | humans |
| `area:*` / `topic:*` | Domain / subject classification | `ideate` | humans, routing |

Built-in GitHub **issue types** `Bug` and `Feature` are assigned by `ideate` based on classification.

## Comment markers

Every comment an agent posts begins with a marker line, so agent comments are always distinguishable from human ones — and from each other:

| Marker | Skill |
| --- | --- |
| `> **⚓️ ideate-agent**` | `ideate` |
| `> **📐 create-prd-agent**` | `create-prd` |
| `> **🔪 slice-prd-agent**` | `slice-prd` |
| `> **👷 implement-issue-agent**` | `implement-issue` |
| `> **🔎 review-pr-agent**` | `review-pr` |
| `> **🔒 security-review-agent**` | `security-review` |
| `> **🧭 knowledge-base-agent**` | `knowledge-base` |

When [`write-a-skill`](skills/productivity/write-a-skill/SKILL.md) authors a new skill that posts comments, it assigns that skill its own distinct marker (e.g. `> **🛠️ <skill>-agent**`) and records it here — this table stays the single source of truth, so no two skills share a marker.

## Conventions

- **Labels and markers are the control plane** — every branch, route, and human-attention hand-off is decided by a label, and every agent comment carries a marker. Skills don't infer state from prose; they read a label, act, and swap it. Human gates are always human-only labels. The **Labels** and **Comment markers** tables are the single source of truth, and `write-a-skill` enforces this on every new skill.
- **`ORG_KB`** — the organisation knowledge base (glossary in `CONTEXT.md` / `CONTEXT-MAP.md`, decisions in `docs/adr/` or Notion) is loaded **once** per run.
- **Token discipline** — load context once, search narrow (ast-grep for code, keyword search for prose), keep a stable prompt prefix for caching, and keep internal reasoning terse. Each pipeline skill carries a **context budget (≤150k, soft)**: the orchestrator holds summaries, the heavy reads live in sub-agents. None of this compression ever touches user-facing text, which stays plain and example-driven.
- **Model tiering** — the mechanical reads and reviews run as sub-agents on **cheap, fast models** (the [`agents/`](agents/) personas: `kb-investigator` on Haiku, the reviewers on Sonnet); **anything that writes code stays on the strong model** (the `implement-issue` build, review-pr's inline fixer). This is the main cost lever for running the pipeline.
- **Instincts in the loop** — the project-tier `.instincts/` rules (owned by the `instincts` skill) are a **standards source**: `implement-issue` builds against them and `review-pr` checks against them, so build and review share one rubric and the code is right first time — fewer rework loops.
- **Plain language** — user-facing questions and reports assume a non-technical reader: everyday words, quick analogies, and concrete live examples over abstractions.
- **Requirement traceability (`US#`)** — the PRD's User Stories are the origin of truth: each gets a stable `US#` id, **never renumbered**, that threads downstream — `slice-prd` tags every Acceptance Criterion and Implementation-Map step with it, `implement-issue` names tests after it, and `spec-reviewer` returns a `US#` coverage table. Acceptance criteria are written test-shaped (EARS — `When … the system shall …` — or `Given/When/Then`), kept light and optional for trivial cases. This is a *convention*, not a new label or marker — the control-plane tables are unchanged.
- **Build maps as a token lever** — `slice-prd` writes a durable, path-free, `US#`-tagged **Implementation Map** onto each child issue (cheap model, before the human gate); at build time `implement-issue` has `kb-investigator` resolve it to current file:line targets, so the strong model executes a tight map instead of re-exploring the repo. The heavy read stays cheap; the expensive build session stays lean.
- **Agent memory (cache)** — the sub-agents externalise their distilled findings to a gitignored `.agent-memory/` folder (`issue-<n>.md` for `kb-investigator`'s codebase map across the brief→PRD→task chain; `pr-<n>.md` for the reviewers' standards digest + `US#` coverage table), keyed by stable id, every fact SHA-stamped and tagged durable/volatile. On the next turn an agent reads its memory, re-derives **only** the paths changed since that stamp (`scripts/agent-memory.sh stale-paths`), and updates it — so `review-pr`'s rework loop re-reviews the *delta* not the whole PR, and codebase knowledge carries across pipeline stages instead of being re-investigated cold. This is a **non-authoritative cache** and **does not violate** "labels and markers are the control plane": GitHub stays the single source of truth, the cache is always safe to delete (a miss just re-derives cold), and it adds **no new label or marker**.

## Attribution

- The **`ast-grep`** skill is vendored from the official [ast-grep](https://ast-grep.github.io/) project (MIT-licensed) and lightly adapted.
- The **`ideate`** interview methodology is inspired by the `grill-me` and `grill-with-docs` skills.

## License

[MIT](LICENSE) © 2026 Paras Singla
