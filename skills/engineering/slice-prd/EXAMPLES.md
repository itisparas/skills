# slice-prd — examples

## Child-issue body template

Every child issue `slice-prd` creates uses this body. The three checklists are deliberately
distinct: **Definition of Ready** = what must be true before an agent *starts*;
**Acceptance Criteria** = the observable behaviour that proves the slice *works*;
**Definition of Done** = the engineering bar before it can *merge*.

```markdown
> **🔪 slice-prd-agent**

## Parent
- PRD: #<prd>  (<title>)
- Brief: #<brief>  (the original idea this traces back to)

## What to build
A concise description of this **vertical slice** — the end-to-end behaviour it delivers
(schema → API → UI → tests), not a layer-by-layer plan. A finished slice is demoable on
its own.

Avoid file paths and code snippets — they go stale. Exception: a small snippet that
encodes a decision more precisely than prose (a state machine, schema, or type shape) —
inline just the decision-rich bit and note where it came from.

## Definition of Ready  (true before an agent starts — ALL must hold, else the issue parks)
- [ ] The behaviour above is unambiguous — **no open design questions, no undecided seam**
- [ ] Preconditions are explicit — every input, dependency, and assumed state is named
- [ ] Blockers below are merged
- [ ] The relevant glossary terms and ADRs are linked or quoted
- [ ] Test seams to use are identified **and the exact test command to run is known**
- [ ] Project `.instincts/` rules in scope are linked (coding preferences to honour)

## Acceptance Criteria  (observable behaviour that proves it works)
- [ ] <user-visible outcome 1 — phrased as what someone can do/see>
- [ ] <user-visible outcome 2>
- [ ] <edge case / failure path handled>

## Definition of Done  (the bar before merge)
- [ ] Acceptance criteria all met and demoed
- [ ] Tests cover the new behaviour (following the seam noted above) and pass
- [ ] Follows documented coding standards **and `.instincts/` rules** (review-pr Standards axis would pass)
- [ ] No new lint/type errors; docs/glossary updated if terms changed

## Blocked by
- #<blocker issue>      ← or "None — can start immediately"
```

## Parked-proposal comment (Step 4, no human present)

When slicing runs in batch (or the human defers), the breakdown is **not** published as
issues — it's posted as a marked comment on the PRD for async sign-off, and the PRD is
parked with `state:human-review-needed` (off `state:slice-ready`). A human replies, then a
later interactive run reads the reply and publishes.

```bash
gh issue comment <prd> --body "> **🔪 slice-prd-agent**
> ## Proposed slices — needs your sign-off before I create them
> Reply with any merges/splits/re-ordering, or re-run \`slice prd <prd>\` and I'll walk
> through them one at a time. **Nothing is created yet.**
> 1. **<title>** — <clear / needs-a-human> · blocked by <#/none> · stories <…>
> 2. …"
```

## A worked slice (live example used in the Step 4 interview)

PRD #250 — *"Let a customer reset their own password."* The sub-agent (Step 2) returns
three seams and one ambiguity (the email-provider choice isn't decided).

Proposed breakdown shown to the user:

| # | Title | Clear / Needs-a-human | Blocked by | User stories |
| --- | --- | --- | --- | --- |
| 1 | Request-reset endpoint + token storage + happy-path test | Clear | None | US-1 |
| 2 | Reset-link email (provider TBD) | **Needs-a-human** — provider undecided | 1 | US-2 |
| 3 | Set-new-password page + validation + test | Clear | 1 | US-3 |

The coarseness conversation that sets this:

> *A slice is like one working slice of cake — a bit of every layer, not the whole tray of
> sponge with no icing. Slice 1 here is "ask to reset and store a token, with a test that
> proves it" — thin, but it cuts all the way through. Does that feel like the right size, or
> would you rather one bigger "whole reset flow" ticket? I'd keep them split — each is its own
> demo, and slice 2 is genuinely blocked on a decision you still need to make.*

On publish: #1 and #3 get `type:task` + `state:buildable`; #2 gets `type:task` +
`state:human-review-needed` with the open question (which email provider?) called out in its
body. PRD #250 is marked `state:sliced` (off `state:slice-ready`) and stays open as the epic
with a checklist of the three.
