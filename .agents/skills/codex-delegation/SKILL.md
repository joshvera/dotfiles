---
name: codex-delegation
description: Use in Codex before delegating work, dispatching a separate Codex task (planner, advisor, explorer, coder, reviewer), choosing role models, or starting a contract-handoff. Codex-specific mechanics that complement the shared ~/.codex/AGENTS.md.
---

# Codex delegation

Codex-specific mechanics. The shared rules (independent review triggers, verification, testing) live in `~/.codex/AGENTS.md` and apply here unchanged.

<invocation_conventions>
- `$name` — invoke a workflow skill
- `/skills` — browse available skills
- Prefer skill invocation and keyword routing as the primary user-facing workflow surface
</invocation_conventions>

<contract_handoff_trial>
- For substantive behavior changes spanning tasks or milestones, the parent uses `contract-handoff` alongside the existing planning/execution workflow. Small direct fixes and prose edits need no new contract artifacts.
- Favor elegant, concise contracts: reuse the existing authoritative PRD or section per capability, capture only consequential invariants and discriminating scenarios, and adopt only touched behavior. Pin handoffs to the agreed contract revision and outstanding scenario IDs; keep evidence and acceptance in the existing execution ledger.
- This trial adds no approval phase, duplicate checklist, or review per task. Batch reviews by consequential behavior under the existing review policy. Simplify or propose dropping the trial when its records duplicate existing information without reducing ambiguity.
</contract_handoff_trial>

## Delegation and role routing

The parent owns scope, coordination, integration and acceptance. Decide whether to implement locally or delegate based on the task's scope, isolation needs, available models, and the user's direction. Delegation is optional; do not require a specific agent, model, or external worker for implementation.

Planning, advisory assessment and standalone review are separate-task roles: create a separate Codex task for them. `superpowers:subagent-driven-development` implementers use the separate Codex task adapter above; reviewers dispatched by that workflow follow its agent procedure. Bounded factual exploration may still use a sub-agent when it improves throughput.

Use the personal role skills inside standalone role tasks: planner for substantial sequencing or decomposition, advisor for a named diagnostic or architectural uncertainty, and reviewer for independent acceptance assessment. Use the execution skill's own prompts and review gates for roles it dispatches; do not layer a personal role skill onto them unless the workflow explicitly calls for it. Give each task an objective, constraints, source references, repository/worktree, owned files and expected evidence. Use a neutral brief for advice and review. Avoid overlapping edits.

Name every separate Codex task `<exact parent title> · <canonical role>`. Resolve the parent title from the current task identified by `CODEX_THREAD_ID`; do not paraphrase it. Canonical roles are `Planner`, `Advisor`, `Explorer`, `Coder`, `Milestone Reviewer` and `Final PR Reviewer`. Use the same title for every continuation of a parent-role pair because only one task for that pair should be active at a time.

Before creating a separate Codex task, look for an existing task for that parent-role pair. Prefer a task ID retained from the original `create_thread` result or a prior child callback. Otherwise use `list_threads` to find the exact conventional title and narrow candidates by project, host, working directory, status and recency; inspect `list_archived_threads` when relevant. Confirm a candidate with `read_thread`, including its original objective and embedded parent task ID, before reusing it. Continue a confirmed task with `send_message_to_thread`, and rename a confirmed legacy task to the convention before continuing it. Create a new task only when no credible match exists, the role or parent has changed, or the existing task cannot safely continue because of an explicit environment, ownership or history constraint. Do not guess between ambiguous candidates; ask the user to choose.

Every separate Codex task prompt must include a return protocol. Identify the dispatching task as the parent and include its exact task ID from `CODEX_THREAD_ID`. Before its final response, the child must call `send_message_to_thread` with that parent task ID for every terminal outcome: success, changes requested, blocked or failed. The callback must identify the child by title and task ID and concisely report the outcome, evidence, blockers and remaining uncertainties. If the child needs parent input earlier, it must use the same callback path for a focused question. The child must also leave its complete result in its own final response, but it must not rely on that final response, shared artifacts or task status to notify the parent.

For separate Codex tasks, do not call `wait_threads` to await completion, keep the parent active, register interest or receive results. End the parent turn after dispatch. The child's required `send_message_to_thread` callback is the sole completion-notification path; after receiving it, the parent may use `read_thread` to inspect the complete result. Do not poll with repeated task listings, reads or status checks. For in-session agents, follow the execution skill's waiting and reconciliation procedure instead.

| Role | Default model / effort |
| --- | --- |
| Parent / daily implementation | `gpt-5.6-sol` / `high` |
| Planner | `gpt-6-astra` / `high` |
| Advisor | `gpt-6-astra` / `medium` |
| Explorer | `gpt-5.6-luna` / `low` |
| Milestone reviewer | `gpt-5.6-sol` / `high` |
| Final PR reviewer, when warranted | `gpt-6-astra` / `medium` |

Use Astra High for ordinary planning. Escalate planning to Astra Xhigh only when the task requires choosing between credible competing architectures, or when a wrong plan could corrupt accounting, migration state, concurrency guarantees, recovery behavior or an equivalently costly invariant. Large scope or a long task list alone does not justify Xhigh.

Escalate advice and reviews to Astra High for conflicting evidence, subtle accounting/concurrency/recovery invariants, difficult cross-system interactions or costly architectural decisions. Milestone reviews may use Astra Medium for a focused consequential question; address these risks when they arise, not only at final review.

Explicit user model choices override defaults. The parent default is a routing preference, not permission to switch an active task's model silently.
