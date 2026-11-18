# Dispatch a specialist through herdr

Use an explorer for a bounded factual lookup, an advisor for a named diagnostic or architectural uncertainty, and a reviewer for an independent assessment under the existing review policy. Routine local inspection needs no extra session. Specialists read their role skill, stay read-only, and do not delegate further.

1. Read the parent's supplied AGENTS.md model/effort policy and the chosen role skill. Resolve the exact model and effort for the question, honoring explicit overrides. If the policy, required model, or CLI is unavailable, return `needs-input` rather than substituting. Herdr is the authorized session transport here; do not require desktop task APIs or use their callback route.
2. Inspect `herdr agent list`. Reuse only a specialist whose recorded session, originating delegation, role, and completed assignment match; start fresh for a new independent review. Record your own pane, terminal, and recognized Devin session using `herdr pane current --current`. Preserve the inherited server context.
3. Read installed `herdr tab create --help`, `herdr agent start --help`, and `codex --help` as needed. Create a tab in your current workspace with the assignment cwd and `--no-focus`. Use the returned root pane, never a guessed ID. Start a uniquely named Codex agent with the resolved model and reasoning effort:

   ```sh
   herdr tab create --workspace "$workspace_id" --cwd "$repo" --label "$role_label" --no-focus
   herdr agent start "$specialist_name" --kind codex --pane "$specialist_pane" -- --model "$role_model" -c "model_reasoning_effort=\"$role_effort\""
   ```

   Verify and retain its pane, terminal, and recognized session identity. Do not change trust, permissions, or authentication to force startup. Preserve unrelated occupants and retain specialist tabs for parent inspection.
4. Supply a focused brief: unique subtask ID and round, originating SWE delegation/round, role and skill path, routing policy path and resolved model/effort, repository, question, constraints, primary sources, exact revision or working-diff scope, expected evidence, and your verified callback identity. Review briefs must be neutral and identify the contract, changed scope, and available checks. Require a callback for every terminal outcome or necessary question, plus the complete result in the specialist's final response.
5. Submit with `herdr agent prompt` without `--wait`, then end your turn. This yield is awaiting a specialist, not a terminal outcome of your implementation assignment; do not send a premature parent success or needs-input callback. Do not poll or install completion watchers.

## Return to SWE

The specialist sends `SPECIALIST_CALLBACK subtask=<id> round=<n> outcome=<success|changes-requested|failed|blocked|needs-input>`, its role/pane/session identity, assessed revision, evidence/findings, and remaining uncertainty to the dispatching SWE pane. Include this instruction in its brief: follow the worker skill's **Explicit callback** and **Callback recovery** delivery rules, replacing the receiver with the verified Devin identity and using this marker. Do not send the result directly to the original Codex parent or use desktop messaging. Callback readiness waits remain bounded; a local final alone is not delivery.

On a callback, verify subtask/round and specialist identity, read its complete result, and refresh relevant git status/diff. Apply supported findings within your existing ownership and contract. Resume implementation or give the specialist a bounded follow-up; escalate scope changes, disputed consequential findings, and unavailable required resources to the original parent. Your final parent callback includes specialist identities, exact review scope, findings and their resolution, and unresolved limitations. Specialist success is evidence, not parent acceptance.
