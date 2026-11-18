---
name: herdr-swe
description: Delegate implementation to Devin SWE-2 through herdr, inspect and communicate with its pane, and resume Codex only on an explicit worker callback. Use when the user requests SWE-2 implementation through herdr.
---

# Delegate to SWE-2

Codex owns scope and acceptance; Devin SWE-2 owns the assigned implementation. This workflow targets a Codex CLI conversation inside herdr. A pane prompt does not wake a Codex desktop task. Do not invent a desktop bridge or replace the requested model with Fusion, Adaptive, or another implementer.

## Establish the route

1. Verify `HERDR_ENV=1`. If absent, explain that dispatch needs a Codex CLI pane inside herdr and stop before controlling any live session. Authoring or reading these instructions does not require a live pane.
2. Read `herdr --skill` unless already loaded. Use installed CLI help for syntax. Preserve the inherited server/session context for every command.
3. Run `herdr pane current --current` and `herdr agent get "$HERDR_PANE_ID"`. Record the returned parent pane ID, terminal ID, and `agent_session` identity. Require a recognized Codex agent and session identity before unattended dispatch. Missing identity needs integration setup, not a guessed task ID.
4. Check `devin models list` and `devin skills show herdr-swe-worker`. Default to the available exact `swe-2-high` model unless the user chooses another SWE-2 effort. If unavailable, report the blocker. If the worker skill is not discoverable, supply its verified absolute path in the brief and require the worker to read it before editing.

## Contract handoff

For substantive behavior changes, apply [contract-handoff](../contract-handoff/SKILL.md) and include its [handoff block](../contract-handoff/references/handoff-block.md) in the existing brief. Supply the implementation baseline, accessible pinned contract revision, owned scope, outstanding scenario IDs and required evidence, existing acceptance ledger, and review boundary. A moving worktree path is not a pinned revision; use an exact commit or accessible immutable snapshot with a content hash. Small direct fixes need no new contract artifacts.

Make the assigned completion boundary explicit: all listed outstanding scenarios and required checks, or a deliberately bounded subset. A correction within an ongoing assignment does not silently shrink it to that correction. Reference accepted work in the existing ledger rather than redispatching it.

## Dispatch

Inspect existing agents before creating one. Reuse only a worker whose recorded session and assignment match this parent, and whose previous assignment is finished. Never send a second assignment to a working or blocked agent.

For a new worker, inspect the current pane layout. Split right for a wide pane or down for a narrow one, preserving cwd and focus:

```sh
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Use the returned pane ID and a unique live agent name:

```sh
herdr agent start swe-coder --kind devin --pane "$worker_pane" -- --model swe-2-high
```

Startup readiness is allowed; waiting for implementation completion is not. Run `herdr agent get "$worker_name"` after startup and record its terminal and session identity alongside the parent mapping. Require a recognized Devin session before dispatch. Do not change permission mode, repository trust, or authentication to bypass a blocked startup. Read the blocked UI and report the actual requirement.

Give the worker a brief with these fields:

- Unique delegation ID and round number; parent pane, terminal, and session identity; worker name/pane; inherited herdr server context.
- Exact repo/cwd, objective, owned files, constraints, acceptance scenarios, and required checks. Reference an existing authoritative plan or contract rather than duplicating it.
- Explicit instruction to read `herdr-swe-worker`, retain implementation ownership as SWE-2, preserve unrelated changes, and return success, failed, blocked, or needs-input through the parent pane.
- Verified absolute path to the current AGENTS.md role model/effort policy and accessible explorer/advisor/reviewer skills. SWE may create herdr tabs for bounded read-only specialists using that routing; these sessions return to SWE, while Codex retains scope and acceptance. For these specialists, the herdr route replaces the desktop task transport and callback, not the role or review policy.
- Callback payload: delegation ID/round, worker identity, outcome, changed files, actual checks/results, risks, and focused question if needed. For a contract handoff, include the contract revision, implementation revision or working-diff evidence, scenario-to-evidence mapping, and remaining scenario IDs.

Retain that mapping in the parent conversation before dispatch. Use safely quoted arguments, or read the brief from a file into a shell variable. Submit once:

```sh
herdr agent prompt "$worker_name" "$brief"
```

**Omit `--wait`. End the parent turn after successful submission.** Do not use polling, `agent wait`, sleeps, heartbeat automations, pane-output watchers, or desktop task waits to wake the parent. An idle/done badge is not a callback. Do not require a startup acknowledgment that wakes the parent unnecessarily.

## Resume and communicate

Only a worker callback or explicit user input resumes coordination. Check the delegation ID, round, worker session, and current git status/diff before accepting a result. Ignore already handled callbacks; a late callback from an older round must not complete a newer assignment.

Use `herdr agent get "$worker_name"` and `herdr agent read "$worker_name" --source recent-unwrapped --lines 120` after a callback or when the user asks for inspection. For long truncated output, ask the worker to write a report to a temporary file. Send scoped corrections with `agent prompt` without `--wait`, then end the turn again. Keep substantive independent review and repository verification requirements.

Reconcile contract callbacks against the pinned revision and outstanding IDs in the existing ledger. `success` means the assigned implementation and required evidence are complete; it does not mean parent acceptance. Keep partial deliveries open and dispatch only the bounded remainder. A green checkpoint does not close other assigned scenarios. Contract changes require an explicit new pin and affected IDs; implementation corrections retain the contract. Reassess affected evidence and preserve unaffected acceptance under the existing review policy.

On ambiguous submission failure, inspect identity and output once before deciding whether retry is safe. Do not duplicate an assignment merely because the command timed out. Never close or interrupt another occupant, and retain the worker pane until acceptance or an explicit cleanup request.

## Operational limit

This is a cooperative terminal protocol, not a durable message broker. It cannot guarantee delivery after a worker crash, closed/replaced pane, blocked parent UI, or server loss. No watchdog is installed. Report that limitation rather than quietly adding periodic wakeups. The worker skill defines bounded callback recovery.
