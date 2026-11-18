---
name: contract-handoff
description: Use when a parent is planning, handing off, or accepting substantive behavior changes across tasks or milestones and needs a durable contract and outstanding acceptance scenarios. Also use when explicitly invoked. Small direct fixes and prose edits do not require contract artifacts.
---

# Contract handoff

Keep agreed behavior easy to find and unfinished work easy to distinguish from accepted work. Favor elegance: the smallest contract that resolves consequential ambiguity. This is a trial extension to the existing workflow, not another planning or approval phase.

The parent applies this skill and gives children concise handoffs. Existing authorization, execution ownership, verification, and review policies remain authoritative. This skill adds no approval gate, separate ledger, or review per task.

## Maintain the contract

- Reuse the capability's existing PRD or normative document. A section can be the authority; a new file is optional. Create a stable contract document only when no suitable authority exists. Adopt only the behavior touched by the current work, without backfilling the repository.
- Write observable behavior, essential invariants, scope/non-goals, and a few discriminating acceptance scenarios with stable IDs. Prefer concrete outcomes to implementation detail. Include failure or lifecycle cases when they distinguish safe behavior from a plausible wrong implementation; avoid an exhaustive matrix by default.
- Keep shared behavior in its owning contract and link to it. Plans hold sequencing and file changes; ledgers hold progress. Replace superseded wording in the authoritative contract and mark conflicting old drafts as historical rather than appending competing instructions.
- The parent reconciles proposed changes under existing authority. Pin the agreed document to a Git commit before implementation handoff. For agreed uncommitted content that cannot yet be committed, use an accessible immutable snapshot with a content hash; never label a moving worktree as an exact revision. Unagreed edits remain proposals.

## Hand off only the remaining work

Use [the handoff block](references/handoff-block.md) inside the existing brief or dispatch. Identify the implementation baseline, exact contract revision, owned scope, outstanding scenario IDs, evidence needed, and planned review boundary. Reference accepted work in the ledger instead of copying its history.

Ensure the recipient can access the pinned artifacts. Update requirements only when agreed behavior changes; fix implementation violations to meet the existing contract. If the contract changes mid-task, send the new revision and affected IDs explicitly, update the ledger, and reassess only impacted evidence. Continue independent work while a consequential ambiguity is resolved.

## Reconcile and accept

In the existing plan-review brief, ask the reviewer to check the affected contract's behavior, non-goals, consequential invariants, acceptance scenarios, contradictions, and unnecessary complexity. In implementation review, ask for evidence against those same requirements. Include these checks in workflow-owned review prompts too, without adding another reviewer role or loading an extra role skill.

Use [the acceptance table](references/acceptance-table.md) in the existing execution ledger. Extend or replace overlapping status fields rather than maintaining a second checklist. Distinguish implementation, verification evidence, and parent acceptance. Keep uncovered scenarios and partial deliveries open; hand off the bounded remainder.

At handoff and acceptance boundaries, reconcile the current acceptance table with the latest code and contract revisions. Replace stale status text and mark affected evidence as superseded when it no longer supports the changed implementation or contract. Keep historical detail in the existing log; preserve acceptance for unaffected scenarios.

Define independent review batches around coherent consequential behavior, such as accounting admission or recovery ownership. Task count does not determine review count. Preserve required reviews; use parent checks between boundaries. After review, the parent verifies straightforward corrections and closes findings. Return to the reviewer for consequential contract changes, disputed or unresolved findings, or insufficient evidence. Final review is warranted for consequential interactions or changes not already covered.

At ordinary handoff, mention trial overhead only when useful: did these artifacts prevent ambiguity or merely duplicate existing records? Simplify redundant fields; propose dropping the trial if it adds no value. Do not create a retrospective task or metrics system.
