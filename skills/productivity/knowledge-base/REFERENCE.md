# Knowledge Base — Reference

Per-backend detail for the `knowledge-base` skill. Read only the section for the backend the user picked. The SKILL.md is the procedure; this is the lookup.

## The backend menu

| Choice | Live pipeline (briefs/PRDs/tasks/review) | Durable knowledge (vision/arch/glossary/ADRs/memories) |
|---|---|---|
| **Local** | Local issue files under `10-issues/` | Numbered-folder vault |
| **GitHub** | GitHub Issues + `type:*`/`state:*` labels | Markdown under `/docs` in the same repo |
| **Notion** | A Notion "Issues" database | One Notion database per doc-type |
| **Hybrid** | **GitHub** Issues + labels | **Notion** databases *or* the local vault |

Hybrid is the recommended default for a team already on GitHub: GitHub is where work moves and is gated; the knowledge half is where lasting decisions are read. The split is fixed — GitHub always runs the pipeline; the user only chooses whether the *knowledge* half is Notion or local.

## kb-config.yml

The single source of truth, written at the KB root (the vault root for local; the repo root that holds `AGENTS.md` for GitHub/Notion/hybrid). The SessionStart hook checks for this file; every other skill reads it to find the backend.

```yaml
# kb-config.yml — owned by the knowledge-base skill
backend: hybrid              # local | github | notion | hybrid
pipeline: github             # where issues + labels live (github, or local)
knowledge: notion            # where durable docs live (notion | local)
github_repo: inviscel/agentic-inviscel   # owner/name — omit if no GitHub
notion_root: <parent-page-id>            # omit if no Notion
org_kb_path: .                # path to the vault root, for local/hybrid-local
created: 2026-06-17           # absolute date, never "today"
```

## Local — the numbered-folder vault

`scripts/scaffold-local.sh <ORG_KB>` builds the structure below, an `index.md` in every folder, `00-meta/conventions.md` (the structural contract), and `00-meta/document-templates/` (prd, brief, issue, adr, doc). It mirrors the proven Inviscel layout.

```
INDEX.md · AGENTS.md · CLAUDE.md(@AGENTS.md) · kb-config.yml
00-meta/      how the vault works: conventions, templates, changelog
01-overview/  vision, goals, glossary
02-architecture/  system design (sub-folders per product)
03-research/  dated, concluded investigations
04-prds/      requirements, by status: draft/ active/ complete/
05-plans/     roadmaps, plans, work queues
06-status/    now.md, decisions.md, log/, incidents/
07-reference/ stable lookup: spec, schemas, examples
08-briefs/    scoped work briefs: draft/ active/ complete/
09-company/   brand, philosophy, voice
10-issues/    grabbable issues, by status: draft/ active/ complete/
11-adrs/      Architecture Decision Records (full)
12-memories/  append-only memory-log.md (standing instincts)
archive/      superseded docs, never deleted
```

**Every doc opens with frontmatter** (`title`, `status`, `created`, `updated`, `tags`, `related`); `kebab-case.md` names; status is encoded twice (frontmatter + folder) and moved atomically. The generated `conventions.md` carries the full contract.

## GitHub — the control plane

`scripts/setup-github-labels.sh <owner/repo>` creates the pipeline labels (idempotent — skips any that exist):

| Label | Meaning |
|---|---|
| `type:brief` · `type:prd` · `type:task` | The artifact's stage |
| `state:prd-ready` · `state:slice-ready` · `state:agent-ready` | **Human-only gates** agents never apply |
| `state:sliced` · `state:blocked` · `state:merge-ready` · `state:human-review-needed` | Pipeline states set by skills (an **untyped** `state:human-review-needed` issue is `ideate`'s "needs triage" case) |
| `area:*` / `topic:*` | Domain / subject classification (created on demand) |

It also ensures the built-in issue types `Bug` and `Feature` exist. These labels are the contract the whole skill family routes on — see the README "Labels" table, the single source of truth. The skill **creates** them here but, like every skill, never *applies* the human-only gates.

## Notion

For a Notion backend (or the knowledge half of a hybrid), create one database per doc-type under the chosen parent page via `notion-create-database`, each with a `Status` select (`draft`/`active`/`complete`/`deprecated`/`archived`) and a `Tags` multi-select mirroring the frontmatter contract:

- **Knowledge:** Overview, Architecture, Research, Reference, Company, ADRs, Memories.
- **Pipeline (Notion-only backend):** Briefs, PRDs, Plans, Issues — each with a `Type` and a `State` select mirroring the GitHub labels above, so the same gates exist as values.

Record the created database IDs in `kb-config.yml` under a `notion_databases:` map so later runs and other skills can find them.

## Hybrid wiring

Run both halves and cross-link them: GitHub issues carry a link to the Notion/local PRD or ADR they realise; durable docs link back to the GitHub epic. The principle matches the rest of the system — **one live artifact per piece of work**, links instead of copies.

## AGENTS.md block

Insert (or update) this pointer block; keep AGENTS.md short — a link, not content:

```markdown
## Knowledge Base
Backend: **hybrid** — live pipeline in GitHub (`inviscel/agentic-inviscel`),
durable knowledge in Notion. Structure owned by the `knowledge-base` skill;
backend + coordinates recorded in `kb-config.yml`. Set `ORG_KB` to this root.
```

`CLAUDE.md` is a one-line `@AGENTS.md` so both Claude Code and other runners load the same master file.

## The SessionStart hook (detect & offer)

`scripts/install-hook.sh` merges this into `.claude/settings.json`. It only *offers* — it prints a suggestion and exits, never launching the wizard:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command",
        "command": "test -f kb-config.yml || printf 'No knowledge base found here. Run /knowledge-base to set one up.\\n'" } ] }
    ]
  }
}
```
