# ast-grep — Reference

Cheat sheet for `ast-grep` (`sg`): invocations, rule object, metavariables, recipes, debugging. Load when building a non-trivial rule; simple `sg run --pattern` searches need none of this.

## Invocations

```bash
# Pattern search (one node, no rule file) — the default command
sg run --pattern 'console.log($ARG)' --lang javascript .
sg -p 'class $NAME' -l python path/             # short flags
sg -p 'function $F($$$)' -l js --json .          # JSON output

# Rule search (structural / relational)
sg scan --rule rule.yml path/                    # from a file
sg scan --rule rule.yml --json path/

# Inline rule — no file. Escape metavars as \$ so the shell doesn't expand them
sg scan --inline-rules 'id: t
language: javascript
rule:
  kind: function_declaration
  has: { pattern: await \$E, stopBy: end }' path/

# Test a rule against a snippet via stdin
echo 'const x = await fetch();' | sg scan --inline-rules 'id: t
language: javascript
rule: { pattern: await \$E }' --stdin

# Inspect how code parses / how a pattern is read — your debugger
sg run -p 'class User { constructor() {} }' -l js --debug-query=cst
sg run -p 'class $N { $$$BODY }'              -l js --debug-query=pattern
```

`--debug-query` formats: `cst` (every node incl. punctuation), `ast` (named nodes only), `pattern` (how `sg` interprets your pattern). Use it to find the right `kind` name and to see why a pattern won't match.

## The stopBy rule (read this first)

Relational rules (`inside`, `has`, `precedes`, `follows`) default to `stopBy: neighbor` — they only check the **immediate** surrounding node, so a descendant a few levels down is silently missed. **Almost always add `stopBy: end`** to search the whole direction (up to root for `inside`, down to leaves for `has`).

```yaml
has:
  pattern: await $EXPR
  stopBy: end
```

`stopBy` values: `neighbor` (default), `end` (full traversal), or a rule object (stop when a surrounding node matches it, inclusive).

## Rule object

A node matches a rule when it satisfies **all** fields present (implicit AND). At least one positive key (`pattern`/`kind`) must be present. Use an explicit `all` when later sub-rules reuse metavariables captured by earlier ones — it guarantees match order.

| Key | Category | Matches when… | Example |
| :-- | :-- | :-- | :-- |
| `pattern` | atomic | node matches a code pattern | `pattern: console.log($ARG)` |
| `kind` | atomic | node is this tree-sitter kind | `kind: call_expression` |
| `regex` | atomic | node text matches a Rust regex | `regex: ^[a-z]+$` |
| `nthChild` | atomic | node is the nth named child (1-based; An+B ok) | `nthChild: 1` |
| `range` | atomic | node spans these 0-based line/cols | `range: { start: {line,column}, end: {…} }` |
| `inside` | relational | node sits inside a match of the sub-rule | `inside: { kind: class_body, stopBy: end }` |
| `has` | relational | node has a descendant matching the sub-rule | `has: { pattern: await $E, stopBy: end }` |
| `precedes` | relational | node appears before a match of the sub-rule | `precedes: { pattern: return $V }` |
| `follows` | relational | node appears after a match of the sub-rule | `follows: { pattern: import $M from '$P' }` |
| `all` | composite | every sub-rule matches | `all: [ {kind: …}, {pattern: …} ]` |
| `any` | composite | some sub-rule matches | `any: [ {pattern: foo()}, {pattern: bar()} ]` |
| `not` | composite | the sub-rule does not match | `not: { pattern: console.log($A) }` |
| `matches` | composite | a named utility rule matches (reuse/recursion) | `matches: my-util-rule` |

`inside`/`has` also take `field:` to require the match be a specific named sub-node (e.g. `field: operator`).

`pattern` can be an object for ambiguous code: `selector` pins which parsed node to use, `context` supplies surrounding code so it parses, `strictness` tunes the match algorithm (`cst`/`smart`/`ast`/`relaxed`/`signature`).

## Metavariables

| Form | Captures | Notes |
| :-- | :-- | :-- |
| `$VAR` | one **named** node | `$META`, `$_`. Not `$lower`, `$1`, `$KEBAB-CASE`. Reusing `$A` requires equal text: `$A == $A` matches `a == a`, not `a == b`. |
| `$$VAR` | one **unnamed** node | operators/punctuation, e.g. the `+` in `a + b` |
| `$$$VAR` | zero or more nodes | arg lists, statement bodies: `foo($$$)`, `function $F($$$A) { $$$ }` |
| `$_VAR` | not captured | leading `_` skips capture; same name may match different text; faster |

A metavariable must be the **entire** text of one AST node. These don't work: `obj.on$EVENT`, `"hello $WORLD"`, `a $OP b` (use `$$OP`), `$jq`.

## Recipes

```yaml
# function that contains an await
rule:
  kind: function_declaration
  has: { pattern: await $EXPR, stopBy: end }
```
```yaml
# console.log inside a class method
rule:
  pattern: console.log($$$)
  inside: { kind: method_definition, stopBy: end }
```
```yaml
# async fn using await but with NO try/catch
rule:
  all:
    - kind: function_declaration
    - has: { pattern: await $EXPR, stopBy: end }
    - not:
        has: { pattern: 'try { $$$ } catch ($E) { $$$ }', stopBy: end }
```
```yaml
# any console method
rule:
  any:
    - pattern: console.log($$$)
    - pattern: console.warn($$$)
    - pattern: console.error($$$)
```

## Debugging a rule that won't match

1. Run `sg run -p '<your code>' -l <lang> --debug-query=cst` to see the real tree and the correct `kind` names.
2. Missing deep matches → add `stopBy: end` to the relational rule.
3. Metavariable ignored → make sure it's the only text in its node (see above).
4. Too complex → split into smaller sub-rules under `all` and test each.
5. Visualise it fast in the [ast-grep playground](https://ast-grep.github.io/playground.html).
