---
name: herdr-swe-worker
description: Use when Devin SWE-2 receives a Codex implementation assignment through herdr with an explicit parent pane and callback contract.
---

# SWE-2 implementation worker

Implement the assigned scope in this Devin session. Codex owns acceptance. Remain on the requested SWE-2 model and retain implementation ownership. You may delegate bounded specialist work as described below; do not transfer the implementation assignment or substitute its model. Read repository instructions and preserve unrelated work.

## Before implementation

Verify `HERDR_ENV=1` and read `herdr --skill` unless already loaded. Require the delegation ID/round, objective, cwd, ownership, checks, and parent pane/terminal/session identity from the brief. Inspect the parent with `herdr agent get "$parent_pane"` in the inherited server context. Check the recognized Codex agent and exact identity against the brief. Never infer the parent from UI focus or sidebar order.

If the callback route is missing or mismatched, report the problem locally before editing. Do not select a different Codex pane. If the route is valid but task details are missing, use a `needs-input` callback. No routine startup or progress callback: the parent should remain idle until there is a result or a necessary decision.

## Implement and verify

Refresh git status/diff, inspect the relevant code, implement within ownership, and run the required checks. Fix failures within scope. Return an honest failed/blocked outcome when completion needs unavailable resources or an out-of-scope decision. Do not commit, push, deploy, or expand scope unless the assignment authorizes it.

## Follow the assigned contract

For a substantive assignment with a contract handoff, read the pinned contract and existing acceptance ledger before editing. Check the baseline, owned scope, outstanding scenario IDs, required evidence, and completion boundary. If a referenced revision is inaccessible or consequential requirements conflict, send `needs-input` with the specific gap; do not substitute a moving draft or invent acceptance criteria. Small direct fixes need no contract paperwork.

Keep the contract's invariants binding while fixing tests. Propose behavior or evidence-requirement changes through `needs-input`; implement them only after the parent supplies the agreed revision and affected IDs. A scoped correction does not discard the rest of the assignment. Preserve accepted scenarios and update implementation/evidence for the outstanding ones in the existing ledger, leaving acceptance to the parent.

Before returning `success`, reconcile every assigned outstanding ID with the actual changed revision and required check results. Return scenario-to-evidence links and any remaining IDs. A passing checkpoint with assigned work still open is not success: continue within scope, or use `needs-input`, `blocked`, or `failed` when the corresponding condition prevents completion. Do not create a second ledger or claim parent acceptance.

## Specialist help

You may start separate herdr tabs for bounded [explorer](../explorer/SKILL.md), [advisor](../advisor/SKILL.md), and [reviewer](../reviewer/SKILL.md) work when it helps the assignment. Use the current role model/effort policy in the AGENTS.md supplied by the parent, including escalation rules and explicit user overrides. Do not assume specialists run SWE-2 or inherit your model. Read [specialist dispatch](references/specialist-dispatch.md) before starting one.

Specialists stay read-only and return to you. You own implementation and synthesis; the original Codex parent owns scope and acceptance. Supply independent reviewers with fresh context and a neutral brief. Forward their complete findings and assessed revision with your result so the parent can reuse valid review evidence under the existing review policy. Specialist advice does not authorize a contract or scope change.

## When to ask the parent

Use a `needs-input` callback before proceeding when:

- The task appears to require a new subsystem, framework, or substantial test infrastructure beyond the agreed approach.
- Existing code and repository guidance conflict in a way that changes the implementation choice.
- Making a check pass would require weakening assertions, normalizing meaningful fields, inventing successful responses, or bypassing production guards.
- Several focused diagnostic attempts leave the same blocker unexplained and you cannot identify a discriminating next check.
- The proposed fix crosses assigned ownership or changes a previously accepted contract.

Include the observed evidence, attempts made, remaining uncertainty, and your recommended next step in the focused question. Follow the callback protocol below, then end the turn for the parent's response. Handle routine implementation choices and initial test failures within scope; they do not require escalation on their own.

## Explicit callback

A turn yielding solely for a dispatched specialist result needs no parent callback. Before ending a completed, failed, blocked, or needs-input assignment turn, prepare one concise callback:

```text
SWE_CALLBACK delegation=<id> round=<n> outcome=<success|failed|blocked|needs-input>
Worker: <name, pane, session identity>
Changes: <files and behavior>
Checks: <commands, results, failures and unrun checks>
Contract: <pinned revision, when assigned>
Evidence: <implementation revision or working-diff evidence; scenario IDs -> results/artifact paths>
Remaining: <outstanding scenario IDs, risks, or focused question>
```

Omit contract-specific fields for small direct fixes without a contract handoff. Link detailed evidence in the existing report or ledger rather than pasting logs.

Set `parent_pane` and `callback` from the verified brief and prepared text, using safe shell quoting. Re-read the parent's identity immediately before sending. Require the same terminal and session and an `idle` or `done` state, then submit:

```sh
herdr agent prompt "$parent_pane" "$callback"
```

**Do not add `--wait`.** Waiting for Codex's next turn can deadlock coordination. A successful command confirms terminal submission, not that Codex consumed or accepted the result. Leave the complete outcome in your own final response as well. A local final response, done badge, notification, or report file alone is not a callback.

## Callback recovery

- Parent still working: allow the dispatching parent to finish. Use a bounded `herdr agent wait "$parent_pane" --until idle --until done --timeout 30000`, then recheck identity. This is a worker-side readiness wait, not a parent completion watcher. At most two readiness waits per outcome; never send into a working parent assuming durable queuing.
- Parent blocked/unknown: inspect with `agent read`. Do not answer approval dialogs, send control keys, or force input. Report callback undelivered locally. Permission-gated tool execution may itself require user intervention before any callback is possible.
- Parent closed, replaced, or identity changed: do not send to the new occupant or guess a replacement. Preserve the result locally and report the missing route.
- Send failed or timed out: read parent state/output once. A timeout may follow delivery. If the callback marker is visible, do not resend. Retry once only when the error proves no bytes were submitted and the same parent is now ready. Otherwise mark delivery uncertain locally and stop, preserving the same delegation ID/round for reconciliation.

Do not repeatedly retry, install a timer, use a desktop task tool, or switch servers to obtain a wakeup. After sending, finish this turn and wait for a new assignment. If Codex requests corrections, use its new round number; do not replay the old success callback.
