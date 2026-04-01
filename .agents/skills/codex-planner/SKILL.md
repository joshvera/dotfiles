---
name: codex-planner
description: Delegate planning to Codex/GPT. Returns dense, AI-optimized plan (not prose). Caller specifies reasoning effort (high/xhigh) based on complexity.
context: fork
model: haiku
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Codex Planning Delegation

Delegate architecture and design work to Codex/GPT-5. Return response verbatim.

## Input from Caller

The caller (main agent) should specify:
- **Task description**: What to plan
- **Reasoning effort**: `high` or `xhigh` based on complexity
  - `high`: Most planning tasks
  - `xhigh`: Complex architecture, critical systems, novel problems

## Process

1. Gather: working directory, user request, relevant file paths
2. Determine reasoning effort from caller's request (default: `high`)
3. Build 7-section prompt (template below)
4. Execute:

```bash
codex exec -m gpt-5.2-codex -c model_reasoning_effort="[high|xhigh]" --sandbox read-only -C "[PROJECT_DIR]" "[PROMPT]"
```

5. Return FULL output verbatim - do not summarize

## 7-Section Prompt Template

```
1. TASK: Design/plan [feature/system] for [goal].

2. EXPECTED OUTCOME: Implementation-ready plan in dense, AI-agent format.

3. CONTEXT:
   - Architecture: [description or "explore codebase"]
   - Relevant: [file paths/patterns]
   - Goal: [what to build]

4. CONSTRAINTS:
   - Must work with: [existing systems]
   - Cannot change: [protected components]
   - Patterns: [conventions to follow]

5. MUST DO:
   - Explore codebase for existing patterns
   - Ask clarifying questions if ambiguous
   - Provide architecture decisions with rationale
   - Break into actionable steps
   - Identify edge cases
   - Estimate effort (Quick/Short/Medium/Large)

6. MUST NOT DO:
   - Write or edit files
   - Over-engineer
   - Assume unclear requirements

7. OUTPUT FORMAT:
   Dense, AI-agent-optimized format. No prose paragraphs.

   ARCHITECTURE:
   - [bullet points, not sentences]

   FILES:
   - path/to/file.ts: [purpose, 5 words max]

   STEPS:
   1. [imperative, minimal]
   2. [imperative, minimal]

   EDGE CASES:
   - [case]: [handling]

   EFFORT: [Quick|Short|Medium|Large]

   QUESTIONS: [if any, else omit section]
```

## Output

Return Codex response verbatim. Format is intentionally terse for token efficiency.
