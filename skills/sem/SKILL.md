---
name: sem
description: Use sem for semantic impact analysis, entity-level blame, and dependency graph exploration when line-level git output is too low-level.
metadata:
  short-description: Semantic impact, blame, and dependency analysis
---

# sem

Use this skill when you need entity-level answers instead of line-level patch output.

## When To Use

- Estimating the blast radius of changing or deleting a function, class, method, type, or config section.
- Finding who last changed each entity in a file.
- Exploring dependency structure before a refactor or review.
- Getting a structured semantic diff for tooling or machine-readable analysis.

`git diff` is already configured globally to use `sem` through Git's external diff hook. Use plain `git diff` for the default semantic diff view. Use `git diff --no-ext-diff ...` when you need raw hunks, patch context, or exact line-by-line output.

## Commands

- `sem impact <entity>`
  Use this to see what other entities may break if the named entity changes.
- `sem impact <entity> --files <path>`
  Narrow the analysis when you already know the relevant file set.
- `sem blame <file>`
  Use this instead of `git blame` when you want ownership/history by function, method, class, or other parsed entity.
- `sem graph`
  Use this to inspect repo-wide dependency structure.
- `sem diff --format json`
  Use this when you need semantic diffs as structured output for automation or further analysis.

## Suggested Workflow

1. Start with `git diff` for the semantic overview of the current change.
2. If one entity is central to the task, run `sem impact <entity>`.
3. If you need ownership or historical context, run `sem blame <file>`.
4. If dependency structure is still unclear, run `sem graph`.
5. Fall back to `git diff --no-ext-diff ...` when exact hunks or patch-ready output matters more than entity summaries.

## Notes

- `sem` works best on supported programming languages and structured formats. On unsupported files it falls back to chunk-based diffing.
- Prefer `--files` on large repos when impact analysis would otherwise scan too broadly.
