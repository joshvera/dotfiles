---
name: codex-review
description: Codex reviews a plan. Returns dense verdict + feedback (not prose). Caller specifies reasoning effort (medium/high/xhigh) based on review depth needed.
context: fork
model: haiku
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Codex Plan Review

Delegate plan review to Codex/GPT-5 for critical second opinion. Return response verbatim.

## Input from Caller

The caller (main agent) should specify:
- **Plan to review**: Content or file path
- **Reasoning effort**: `medium`, `high`, or `xhigh` based on review depth
  - `medium`: Standard plan validation
  - `high`: Complex plans, architectural decisions
  - `xhigh`: Security-critical, novel systems, high-stakes reviews

## Process

1. Read plan file or gather from context
2. Determine reasoning effort from caller's request (default: `medium`)
3. Build 7-section review prompt (template below)
4. Execute:

```bash
codex exec -m gpt-5.2-codex -c model_reasoning_effort="[medium|high|xhigh]" --sandbox read-only -C "[PROJECT_DIR]" "[PROMPT]"
```

5. Return FULL review verbatim - do not filter criticism

## 7-Section Prompt Template

```
1. TASK: Review [plan] for completeness and correctness.

2. EXPECTED OUTCOME: Verdict + specific feedback in dense format.

3. CONTEXT:
   Plan:
   [PLAN CONTENT]

   Goals: [objectives]
   Constraints: [limits if known]

4. CONSTRAINTS:
   - Evaluate against actual codebase
   - Be practical, not theoretical
   - Consider existing patterns

5. MUST DO:
   - Evaluate: clarity, completeness, architecture, verifiability
   - Simulate doing the work to find gaps
   - Check for over-engineering
   - Identify missing edge cases
   - Provide specific improvements if rejecting

6. MUST NOT DO:
   - Write or edit files
   - Rubber-stamp approval
   - Give vague feedback

7. OUTPUT FORMAT:
   Dense, AI-agent-optimized format. No prose.

   VERDICT: [APPROVE | REJECT | APPROVE_WITH_CONCERNS]

   SCORES:
   - Clarity: [1-5]
   - Completeness: [1-5]
   - Architecture: [1-5]
   - Verifiability: [1-5]

   CONCERNS:
   - [issue]: [why it matters]

   REQUIRED_CHANGES: [if REJECT]
   - [change]

   SUGGESTIONS: [optional improvements]
   - [suggestion]
```

## Output

Return Codex response verbatim. Format is intentionally terse for token efficiency.
