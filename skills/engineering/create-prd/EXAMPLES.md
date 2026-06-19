# create-prd — PRD template

The body `create-prd` posts in Step 5. Write for a non-technical stakeholder first,
an engineer second; use the glossary's terms. Keep it about **decisions**, not code —
file paths and snippets go stale.

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
