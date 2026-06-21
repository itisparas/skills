---
name: ast-grep
description: Structural code search with ast-grep (sg) — match code by its AST shape, not text, in place of grep. Use when searching a codebase for code structures, language constructs, or call sites that text search can't pin down — e.g. "find all async functions without try/catch", "every console.log inside a class method", "calls to this function with these args". This is the shared code-search tool the other skills lean on; load REFERENCE.md only when building a non-trivial rule.
---

# ast-grep

`ast-grep` (`sg`) searches code by its **syntax tree**, not its text. Think of grep as matching letters and `sg` as matching shapes: `console.log($ARG)` finds every log call regardless of what's inside the parens, across reformatting and whitespace, with no false hits inside strings or comments.

Use it for **all code search** in place of `grep`. Keyword/text search stays for **prose** (Markdown, docs).

**Be concise, sacrifice grammar for the sake of concision** — when reporting matches back, return the shape/finding, not echoed walls of code.

## The 90% case — one-line pattern search

Most searches need no rule file at all:

```bash
sg run --pattern 'console.log($ARG)' --lang javascript .
sg -p 'console.log($ARG)' -l js .          # short flags
```

`$ARG` is a metavariable — a hole that matches one node. `$$$` matches zero-or-more (e.g. `foo($$$)` = any arg list). That covers most lookups.

## When you need a real rule

Reach for a YAML rule (`sg scan`) only when the match depends on **structure** — "X *inside* Y", "X that *has* Y", "X but *not* Z". The two things that trip people up:

- **`stopBy: end` on every relational rule.** `inside`/`has`/`precedes`/`follows` default to checking only the *immediate* neighbour, so deep matches silently fail. Add `stopBy: end` unless you have a reason not to. This is the single most common reason a rule "doesn't match".
- **Start simple, then narrow.** Try a bare `pattern` first. If that can't express it, match the node `kind` and add one relational rule. Only reach for `all`/`any`/`not` when a single rule genuinely can't say it.

```bash
# inline, no file needed — note \$ to stop the shell eating the metavar
sg scan --inline-rules 'id: x
language: javascript
rule:
  kind: function_declaration
  has: { pattern: await \$E, stopBy: end }' .
```

## Enforcing it — the grep-guard hook

The pipeline skills all say "use `sg`, not `grep`", but prose is easy to ignore. To give it teeth, install an **advisory** Claude Code hook that watches `Bash` calls and reminds you to switch when a `grep`/`rg` runs against code (extensions like `.ts`/`.py`/`.go`, or a recursive search). It **never blocks** — `grep` over prose, logs, and plain text stays fine.

```bash
skills/utility/ast-grep/scripts/install-grep-hook.sh        # project .claude/settings.json
skills/utility/ast-grep/scripts/install-grep-hook.sh -g     # ~/.claude/settings.json
```

This wires `scripts/grep-guard.sh` as a `PreToolUse` hook on `Bash`. Both scripts are bundled here; the guard degrades gracefully without `jq`.

## REFERENCE.md

The cheat sheet — every `sg` invocation, the full rule-object table, metavariable forms, ready-to-copy recipes, and debugging. **Load it only when you're constructing a non-trivial rule**, not on every search; the pattern search above handles the common case from memory.

Vendored from the official [ast-grep](https://ast-grep.github.io/) project (MIT). The web playground is the fastest way to debug a pattern visually.
