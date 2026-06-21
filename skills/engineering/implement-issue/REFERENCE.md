# implement-issue — the TDD loop

Step 4 of `SKILL.md` builds the task **test-first**. This is the detail. It applies the same whether the "items" are fresh Acceptance Criteria (first build) or `review-pr` findings to address (rework) — each gets a failing test first, then the minimal fix, then a clean-up.

## Find the feedback loops first

Before writing any test, learn how this repo runs its tests, linter, and type checker — don't assume. Look, in order, at:

1. The repo's documented coding standards / `CONTEXT.md` / `AGENTS.md` — they often name the commands.
2. `package.json` scripts, `Makefile`, `justfile`, `pyproject.toml`, `Cargo.toml`, CI workflow files.
3. How existing tests are laid out and named (mirror that convention exactly — placement, naming, helpers).

Hold the three commands in memory: **test**, **lint**, **typecheck**. You'll run them many times; reference them, don't re-derive them.

## The loop — one Acceptance Criterion at a time

Work the **resolved build map** from `SKILL.md` Step 3 (the `kb-investigator` build-map pass turned
the issue's component-level Implementation Map into current file:line targets, in order) — but the
unit of the loop is still one **Acceptance Criterion / `US#`** at a time, test-first. The map tells
you *where*; the criterion tells you *what done means*. For each behaviour from the Acceptance
Criteria, in order:

1. **Red.** Write the smallest test that asserts the criterion and *fails for the right reason*. Run it; confirm it fails because the behaviour is missing, not because of a typo or setup error. A test that passes immediately, or fails for the wrong reason, teaches nothing — fix it before moving on.
2. **Green.** Write the *minimum* code to make that test pass. No extra abstraction, no unrelated changes, nothing the criterion didn't ask for. Run the test; confirm green.
3. **Refactor.** With the test green as a safety net, clean up — names, duplication, shape — so the code reads like the surrounding code (match its idiom, comment density, naming). Re-run the test; it must stay green.
4. **Widen the net.** Run the full feedback loop (test + lint + typecheck). Everything stays green before you start the next criterion. Commit here, small, message referencing the issue (e.g. `feat: confirmation email on order placed (#250)`).

Repeat until every Acceptance Criterion is covered by a passing test and the Definition of Done checklist is satisfied. **In rework**, do the same per `> **🔎 review-pr-agent**` finding: a Spec finding ("requirement X missing") gets a test asserting X, then the code; a Standards finding gets the fix plus, where it makes sense, a test that locks the corrected behaviour in. A finding you disagree with is *not* silently skipped — that's a judgement call, so park it (Step 5, `state:human-review-needed`) and let a human and `review-pr` settle it.

## When a criterion resists a test

Some criteria are awkward to drive test-first (a visual tweak, a config change, a third-party integration with no sandbox). Don't abandon TDD silently:

- Push the testable **core** behind a seam and test *that* (e.g. test the function that decides *what* to render, not the pixels).
- If a criterion genuinely can't be tested in this repo, note it explicitly in the PR body under **Not covered by tests** with the reason — never let it look covered when it isn't.
- If the obstacle is missing infrastructure or an unsettled design call rather than test-awkwardness, that's a **park**, not a workaround — go to Step 5 and route by label.

## Discipline

- **No scope creep.** Build only what the Acceptance Criteria ask for. A good idea outside the task's scope becomes a follow-up note in the PR, not extra code in this branch.
- **Stay on the branch.** All work lands on the feature branch from Step 3; never commit to the default branch.
- **Leave it green.** The branch you open the PR from must have a fully passing feedback loop. If you can't get there, park it (Step 5) — don't open a red PR.
