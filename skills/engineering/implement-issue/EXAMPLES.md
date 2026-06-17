# implement-issue — examples

## Pull request body template

The PR opened in Step 6 uses the marker, closes the issue, and cross-links the PRD and brief so the chain stays auditable:

```markdown
> **👷 implement-issue-agent**

Closes #250.

**Parent PRD:** #240 · **Brief:** #231

## What this builds
<one-paragraph summary in plain language — the behaviour a user now gets>

## Acceptance Criteria → tests
- [x] A confirmation email is sent when an order is placed — `order_confirmation_test.rb`
- [x] No email is sent for a failed payment — `order_confirmation_test.rb`
- [x] The email uses the customer's display name — `email_template_test.rb`

## Feedback loops
- test: `npm test` — green
- lint: `npm run lint` — clean
- typecheck: `npm run typecheck` — clean

## Not covered by tests
<only if applicable — each item with its reason; otherwise omit this section>

## Follow-ups (out of scope for this task)
<good ideas that surfaced but belong in a separate issue/brief — or "none">
```

After opening the PR, label it `state:review-ready` and drop a marker comment on the **issue** so the next run knows a PR exists:

```bash
gh pr edit 251 --add-label "state:review-ready"
gh issue comment 250 --body "> **👷 implement-issue-agent**
> Built → PR #251 (\`state:review-ready\`). Re-run me on this issue, or give me the PR, to pick up review feedback."
```

`review-pr` picks up PRs carrying `state:review-ready` and consumes the label. This skill applies **no** review or merge labels itself.

## Worked example — a single fresh build

A human gates task #250 (*"Send an order confirmation email"*) with `state:agent-ready`. The user types `implement 250`.

1. **Route.** Issue #250 has no `👷 implement-issue-agent` comment → **fresh build.** Claim: `gh issue edit 250 --add-label "state:building" --remove-label "state:agent-ready"`.
2. **Load.** Read #250's checklists, follow Parent to PRD #240 and brief #231, load the glossary (so "order placed" means what the domain says) and the repo's test/lint/typecheck commands.
3. **Plan + branch.** Three Acceptance Criteria → three behaviours. `git switch -c feat/250-order-confirmation-email`.
4. **TDD.** Criterion 1: failing test asserting an email is queued when an order is placed (red) → minimal hook (green) → tidy (refactor) → full loop green → commit. Repeat for criteria 2 and 3.
5. **PR + hand-off.** Push, open the PR from the template, `gh pr edit 251 --add-label "state:review-ready"`, and post the marker comment on #250.
6. **Report.** "Built #250 → PR #251 on `feat/250-order-confirmation-email`, labelled `state:review-ready` for review-pr. All three Acceptance Criteria covered by tests; no follow-ups."

## Worked example — reworking a reviewed PR

`review-pr` interviewed the user and posted a `> **🔎 review-pr-agent**` comment on PR #251: *"Spec — no test covers the failed-payment case; Standards — email send should go through the existing `Mailer` seam, not a direct call."* It tagged the PR `state:blocked`. The user types `implement pr 251` (or just `implement 250` — #250 now carries the marker comment, so it routes to rework either way).

1. **Route.** PR given → **rework mode.** Fetch PR #251, the issue it closes (#250), and review-pr's findings.
2. **Load.** Re-read #250's contract + the two findings — already aligned with the user, so they're agreed work.
3. **Plan.** Check out the PR branch. Two items: the missing test, the `Mailer`-seam refactor.
4. **TDD.** Finding 1: write the failing failed-payment test (red) → confirm it passes against current code or add the guard (green). Finding 2: route the send through `Mailer` → full loop green → commit.
5. **Hand back.** Push to the branch; comment on the PR summarising what changed per finding; `gh pr edit 251 --add-label "state:review-ready" --remove-label "state:blocked"`.
6. **Report.** "Reworked PR #251: added the failed-payment test, moved the send behind `Mailer`. Back to `state:review-ready` for re-review."

## Worked example — parking instead of building

`implement 252`. The task says *"Match the new brand palette"* but the Definition of Ready references a design spec that isn't linked and the colours aren't in the PRD. The build can't proceed honestly:

```bash
gh issue comment 252 --body "> **👷 implement-issue-agent**
> ## Parked: brand palette not specified
> The Definition of Ready cites a design spec, but no palette is linked in the task, PRD #241, or brief #233. I need the hex values (or a link to the spec) before I can build this — e.g. is the primary still \`#1D76DB\`, or the new teal? Once it's added, re-apply \`state:agent-ready\` and I'll pick it up."
gh issue edit 252 --add-label "state:human-review-needed" --remove-label "state:building"
```

No branch, no PR. A human supplies the palette and re-applies `state:agent-ready` to authorise the retry.
