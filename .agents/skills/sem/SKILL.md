---
name: sem
description: "Semantic version control workflow: sem (structural truth) -> inspect (review prioritization) -> weave (coordination + merge semantics)."
metadata:
  short-description: Semantic impact, blame, dependency analysis, and review prioritization
---

# Sem / Inspect / Weave

This skill teaches a single coherent workflow:

sem -> inspect -> weave

Use it when you need entity-level understanding (functions/classes/properties), risk-focused review prioritization, and safe merge/coordination semantics.

If `diff.external = sem-diff-wrapper` is configured, plain `git diff` gives the default semantic diff view. Use `git diff --no-ext-diff ...` when you need raw hunks, patch context, or exact line-by-line output.

## When to Use

- Semantic or entity-level diff analysis (not just line diffs)
- Estimating the blast radius of changing or deleting a function, class, method, type, or config section
- Impact questions (what else breaks if this entity changes?)
- Finding who last changed each entity in a file
- Risk triage (what deserves careful review first?)
- Branch integration prep / semantic conflict analysis
- Multi-agent overlap (avoid false conflicts)

## When Not to Use

- Trivial changes where direct reading is cheaper
- Any workflow that would mutate repo merge configuration by default

## Reasoning Model

1. Discover changes -> sem
2. Understand impact -> sem impact / sem graph / sem blame
3. Prioritize review -> inspect
4. Coordination + merge semantics -> weave

## Tool Roles

| Tool      | Core Role                      | Notes                                                                                                         |
| --------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `sem`     | structural truth               | Entity-level diff/graph/impact/blame. Establishes what changed.                                               |
| `inspect` | review prioritization          | Classifies + risk-scores entities (blast radius, dependents, public API) and groups changes for review order. |
| `weave`   | coordination + merge semantics | Entity-level merge semantics and optional advisory coordination (claims).                                     |

## Trigger Phrases

- semantic diff
- entity-level diff
- use sem to analyze changes
- review this change semantically
- analyze impact of this change
- find risky entities in this diff
- prioritize review for this commit
- prepare safe merge
- detect semantic conflicts

## Typical Workflows

### Review last commit

```bash
sem diff --from HEAD~1 --to HEAD --format json
inspect diff HEAD~1 --format json
```

### Review branch vs base branch

```bash
# Replace <base-ref> with the integration branch, e.g. origin/main or origin/master.
sem diff --from <base-ref> --to HEAD --format json
inspect diff <base-ref>..HEAD --format json
```

### Analyze refactor impact

```bash
sem impact <entity>
sem impact <entity> --files <path>  # narrow scope on large repos
sem graph
```

### Prepare merge safely

```bash
weave preview <target-branch>
```

### Human-readable structural diff via git

```bash
git -c diff.external=sem-diff-wrapper diff <base-ref>..HEAD
git -c diff.external=sem-diff-wrapper diff -- <path>
```

## Weave Safety Rules

Run weave only when:

- merge conflicts exist
- multiple agents/branches touched the same entities or adjacent semantic areas
- preparing branch integration
- semantic conflict context is explicitly needed

Never run `weave setup` unless the user explicitly asks (it mutates repo merge-driver configuration).

## Wrapper Policy

Scripts in `scripts/` are optional helpers.

- You may call `sem`, `inspect`, and `weave` directly.
- Use wrappers only to standardize structured output and reduce boilerplate.
- `sem-diff-wrapper` is a `git diff` external wrapper, not a standalone CLI.

## Notes

- `sem` works best on supported programming languages and structured formats. On unsupported files it falls back to chunk-based diffing.
- Prefer `--files` on large repos when impact analysis would otherwise scan too broadly.

## Output Contract

1. Structural changes (entities) from sem.
2. Review hotspots and risk ranking from inspect.
3. Merge/coordination risks from weave (or explicitly state weave was not needed).
