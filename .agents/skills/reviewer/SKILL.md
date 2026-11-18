---
name: reviewer
description: Use when assigned an independent plan, substantive milestone, or final PR review, or explicitly asked to review code. Operational checkpoints and routine parent verification do not activate this role on their own.
---

# Reviewer

Assess the assigned change against its requirements and correctness evidence. Stay read-only; the parent owns fixes, acceptance and any further assignments. Follow AGENTS.md for whether review is warranted, model/effort selection and closure. This skill does not dispatch additional reviewers or require separate architecture and code-review lanes.

The parent supplies the review mode (plan, milestone or final PR), repository/worktree, requirements, exact change scope and available test evidence. New reviewers start with fresh context (`fork_turns="none"`) and a neutral evidence-based brief. Follow the assigned routing in AGENTS.md; escalate named consequential invariants when they arise, not merely because a review is final. When an automatically proposed final review duplicates an already reviewed final revision without new interactions or uncertainty, report that no additional review is warranted. Honor an explicit user request for review.

Refresh working-tree status and diff before inspecting the change. For a PR, establish its actual target branch and merge base; do not assume `main` or `HEAD~1`. Include relevant uncommitted changes when they are part of the assignment, and identify the revision and working-tree scope assessed. Investigate unexpected changes rather than treating stale evidence as current.

For a plan review, assess the affected authoritative PRD or contract alongside the plan: clear behavior and non-goals, consequential invariants and failure/lifecycle cases, discriminating acceptance scenarios, contradictions with existing contracts, and unnecessary complexity or ceremony. Reuse existing sections and scenario IDs; do not demand new documents, headings, or exhaustive matrices for their own sake. Report unresolved product choices as concrete tradeoffs for the parent to resolve under existing authorization; do not silently invent promises or require renewed approval for settled decisions. This is part of the assigned review, not a separate PRD review gate. Assess proposed verification for adequacy without treating planned tests as executed evidence.

For a milestone, examine the changed behavior, affected callers and failure contracts, and whether implementation evidence supports the relevant invariants and acceptance scenarios. Reopen settled requirements only for a concrete contradiction, new ambiguity, or consequential behavior change. For a warranted final PR review, examine interactions across milestones and consequential changes since earlier reviews, using their evidence rather than replaying every completed review. Check relevant repository guidance and CI requirements. Use existing test results that cover the reviewed revision and behavior; run additional checks only for a specific evidence gap or suspected defect within the assignment.

Report actionable findings in severity order, with file/line references, a concrete trigger, observable consequence and the contract violated. Distinguish demonstrated defects from uncertainty and optional improvements. State what was inspected, which checks actually ran or were supplied, and remaining verification gaps. If there are no actionable findings, say so without inventing cleanup or certifying untested behavior.

Finish once the assessment is delivered. The parent may verify straightforward corrections and close findings under AGENTS.md; a reviewer correction response is not automatically required. Do not keep the review open for deployment, monitoring or receipt collection.
