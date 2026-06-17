#!/usr/bin/env bash
# Create the idea-to-merge control-plane labels on a GitHub repo. Idempotent.
# Usage: setup-github-labels.sh <owner/repo>
set -euo pipefail

REPO="${1:?usage: setup-github-labels.sh <owner/repo>}"

# label  color  description
labels=(
  "type:brief|0E8A16|Lean brief produced by ideate"
  "type:prd|1D76DB|PRD expanded from a brief"
  "type:task|5319E7|Buildable child task sliced from a PRD"
  "state:prd-ready|FBCA04|HUMAN GATE — brief approved to be specced. Agents never apply."
  "state:slice-ready|FBCA04|HUMAN GATE — PRD approved to be sliced. Agents never apply."
  "state:agent-ready|FBCA04|HUMAN GATE — approved to build. Agents never apply."
  "state:sliced|C2E0C6|Child task clear and buildable, awaiting the build gate"
  "state:blocked|B60205|Review found a major issue"
  "state:merge-ready|0E8A16|Both review axes clean"
  "state:human-review-needed|D93F0B|Findings, open questions, or a raw idea needing triage — needs a human"
)

for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<<"$entry"
  if gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" 2>/dev/null; then
    echo "created  $name"
  else
    gh label edit "$name" --repo "$REPO" --color "$color" --description "$desc" >/dev/null 2>&1 \
      && echo "exists   $name (updated)" || echo "skipped  $name"
  fi
done

echo
echo "Note: built-in issue types Bug and Feature are assigned by ideate at classification time."
echo "Control-plane labels ready on $REPO."
