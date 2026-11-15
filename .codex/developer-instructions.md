# Codex-only guidance

Injected into `~/.codex/config.toml` as `developer_instructions` by `scripts/sync-codex-developer-instructions.sh`. Shared guidance lives in `.codex/AGENTS.md`, which Claude Code also imports.

<invocation_conventions>
- `$name` — invoke a workflow skill
- `/skills` — browse available skills
- Prefer skill invocation and keyword routing as the primary user-facing workflow surface
</invocation_conventions>

## Delegation and role routing

The parent owns scope, coordination, integration and acceptance. For an accepted implementation plan, use `superpowers:subagent-driven-development` when its trigger conditions are met and agents are available; otherwise use `superpowers:executing-plans` when its trigger conditions are met. These execution skills own their task, fix, review and acceptance loops.

In the Codex app, adapt `superpowers:subagent-driven-development` implementer dispatches to separate Codex tasks: every implementation task must be dispatched to a separate Codex task using `gpt-5.6-terra` at high reasoning. The parent must not implement that task locally or substitute another model unless the user explicitly directs it. If task creation or the requested model is unavailable, report the failure instead of silently falling back. Use the remaining `superpowers:subagent-driven-development` task, review, fix-loop and acceptance procedures as the orchestration contract.

Implement locally when the applicable execution skill assigns the work to the parent, for small direct changes outside a delegated plan, or when a concrete task-specific ownership, integration or operational constraint makes delegation unsuitable. Generic plan boilerplate that defaults implementation to the parent or requires delegation to be assigned in advance does not override the execution skill. An explicit task-specific ownership constraint should state why local ownership is required.

Planning, advisory assessment and standalone review are separate-task roles: create a separate Codex task for them. `superpowers:subagent-driven-development` implementers use the separate Codex task adapter above; reviewers dispatched by that workflow follow its agent procedure. Bounded factual exploration may still use a sub-agent when it improves throughput.

Use the personal role skills inside standalone role tasks: planner for substantial sequencing or decomposition, advisor for a named diagnostic or architectural uncertainty, and reviewer for independent acceptance assessment. Use the execution skill's own prompts and review gates for roles it dispatches; do not layer a personal role skill onto them unless the workflow explicitly calls for it. Give each task an objective, constraints, source references, repository/worktree, owned files and expected evidence. Use a neutral brief for advice and review. Avoid overlapping edits.

Name every separate Codex task `<exact parent title> · <canonical role>`. Resolve the parent title from the current task identified by `CODEX_THREAD_ID`; do not paraphrase it. Canonical roles are `Planner`, `Advisor`, `Explorer`, `Coder`, `Milestone Reviewer` and `Final PR Reviewer`. Use the same title for every continuation of a parent-role pair because only one task for that pair should be active at a time.

Before creating a separate Codex task, look for an existing task for that parent-role pair. Prefer a task ID retained from the original `create_thread` result or a prior child callback. Otherwise use `list_threads` to find the exact conventional title and narrow candidates by project, host, working directory, status and recency; inspect `list_archived_threads` when relevant. Confirm a candidate with `read_thread`, including its original objective and embedded parent task ID, before reusing it. Continue a confirmed task with `send_message_to_thread`, and rename a confirmed legacy task to the convention before continuing it. Create a new task only when no credible match exists, the role or parent has changed, or the existing task cannot safely continue because of an explicit environment, ownership or history constraint. Do not guess between ambiguous candidates; ask the user to choose.

Every separate Codex task prompt must include a return protocol. Identify the dispatching task as the parent and include its exact task ID from `CODEX_THREAD_ID`. Before its final response, the child must call `send_message_to_thread` with that parent task ID for every terminal outcome: success, changes requested, blocked or failed. The callback must identify the child by title and task ID and concisely report the outcome, evidence, blockers and remaining uncertainties. If the child needs parent input earlier, it must use the same callback path for a focused question. The child must also leave its complete result in its own final response, but it must not rely on that final response, shared artifacts or task status to notify the parent.

For separate Codex tasks, do not treat `wait_threads` as registration, durable notification or result delivery. It is a bounded active wait that can expire or be interrupted by new user input. The required child callback is the notification path; after receiving it, the parent may use `read_thread` to inspect the complete result. Do not poll with repeated task listings, reads or status checks. For in-session agents, follow the execution skill's waiting and reconciliation procedure instead.

Require independent review for substantive implementation milestones, regardless of author: behavior or contract changes with meaningful correctness risk. Money, migration, identity, concurrency and recovery contract changes qualify even with small diffs. Batch related repairs; small, low-risk work may finish with parent verification. Final PR review is warranted only for cross-milestone interactions or unreviewed consequential changes.

After review, the parent verifies corrections and closes resolved findings. Return to the reviewer only for consequential contract changes, disputed or unresolved findings, or insufficient evidence. Operational checkpoints and new evidence from reviewed procedures require applicable parent checks, not renewed review or acceptance of unchanged source. Establish the need for review before selecting a reviewer.

| Role | Default model / effort |
| --- | --- |
| Parent / daily implementation | `gpt-5.6-sol` / `high` |
| Planner | `gpt-6-astra` / `xhigh` |
| Advisor | `gpt-6-astra` / `medium` |
| Explorer | `gpt-5.6-luna` / `low` |
| Delegated coder | `gpt-5.6-terra` / `high` |
| Milestone reviewer | `gpt-5.6-sol` / `high` |
| Final PR reviewer, when warranted | `gpt-6-astra` / `medium` |

Escalate advice and reviews to Astra High for conflicting evidence, subtle accounting/concurrency/recovery invariants, difficult cross-system interactions or costly architectural decisions. Milestone reviews may use Astra Medium for a focused consequential question; address these risks when they arise, not only at final review. Do not escalate or substitute the Terra High implementation model without explicit user direction.

Explicit user model choices override defaults. The parent default is a routing preference, not permission to switch an active task's model silently.
