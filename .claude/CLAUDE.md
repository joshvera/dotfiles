<!-- OMC:START -->
<!-- OMC:VERSION:4.15.1 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<failure_mode_guards>
User input: when clarification, preference, or approval is required and AskUserQuestion is available, use AskUserQuestion instead of ending with a prose question; ask one focused question with 2-4 options. Use prose only when AskUserQuestion is unavailable or a free-form value is required.
Session/worktree continuity: before editing after resume/compaction or inside a linked worktree, re-check `git status --short --branch`, current cwd, and relevant `.omc/state/` or `.omc/handoffs/` artifacts so work does not continue on the wrong branch or stale context.
No fake completion: TODO-style placeholder notes, `test.skip`/`.only`, stub tests, and unimplemented branches are blockers, not evidence. Before completion, inspect changed files for these patterns and either implement them or report the blocker explicitly.
</failure_mode_guards>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State root: `.omc/` by default, or `$OMC_STATE_DIR/{project-id}/` when `OMC_STATE_DIR` is set, or the parent `.omc/` when a `.omc-workspace` marker anchors a multi-repo workspace. Runtime state includes `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`, `.omc/artifacts/`, `.omc/handoffs/`, and `.omc/ultragoal/`. These are ignored operational artifacts by default; `.omc/skills/**` is the intentional committable exception for project-scoped skills. In linked git worktrees, local `.omc/` state is removed with the worktree unless centralized via `OMC_STATE_DIR`.
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.
<!-- OMC:END -->

<!-- User customizations -->
# Claude Global Configuration

Shared personal guidance (also read by Codex): @~/.codex/AGENTS.md

## Workflow Principles

### Plan First
Start complex tasks in Plan mode (shift+tab twice). Iterate on the plan until it's solid before switching to auto-accept edits. A good plan dramatically improves outcomes.

### Plan Mode Delegation
When in plan mode for complex features or architecture decisions:
1. Use `/codex-planner` to delegate planning to Codex/GPT-5
2. Use `/codex-review` to have Codex review your draft plan

Note: Responses are in dense, AI-optimized format (not human prose) for token efficiency. This is intentional - the terse output is complete and actionable.

Reasoning effort (specify when invoking):
- `/codex-planner`: `high` (default) or `xhigh` (complex architecture, novel problems)
- `/codex-review`: `medium` (default), `high`, or `xhigh` (security-critical)

Workflow:
- Complex architecture → `/codex-planner` with appropriate reasoning effort
- After drafting a plan → `/codex-review` for second opinion

Triggers for `/codex-planner`:
- System design or architecture decisions → `high`
- Novel systems, critical infrastructure → `xhigh`
- Multi-file features, API design → `high`

Triggers for `/codex-review`:
- Standard plan validation → `medium`
- Complex architectural review → `high`
- Security-critical, high-stakes → `xhigh`

### Subagent Model Routing

Extends superpowers' **Model Selection** (subagent-driven-development): use the least powerful model that can do the role, and **always pass `model=` explicitly** — an omitted model silently inherits the session's most expensive one. Tiers, cheapest first:

- **Haiku** — mechanical work: 1–2 files with a complete spec, tests/docs, mechanical refactor, isolated low-blast-radius fixes (the plan already contains the code → transcription).
- **Sonnet (default)** — integration and judgment: multi-file coordination, debugging, standard implementation, and standard/review passes. Default for parallel executor lanes and for most reviews. Turn count beats token price, so Sonnet is the *floor* for reviewers and for implementers working from prose.
- **Opus** — architecture/design, the adversarial critic, and the final whole-branch review. Promote exactly ONE "spine" executor lane to Opus when the task has shared-core risk (auth, persistence, concurrency, migrations, cross-cutting state).
- **Fable** — only where judgment concentrates in a *decision*: deep-interview, and first-pass planning on genuinely large/ambiguous work. ~2× Opus ($10/$50 per MTok) — spend it only where it shapes the whole run. **Never default Fable on review loops, executor lanes, or security review.**

Escalate a tier when a subagent returns BLOCKED. Keep **security review on Sonnet/Opus, never Fable** — its cybersecurity classifiers can refuse legitimate security analysis.

**Mechanics (verified 2026-07-01):** "(inherit)" does NOT track the session model — an inherit-spawned planner self-reported `claude-opus-4-8[1m]` while the session ran Fable 5. Pin `model=` and verify by asking the agent to self-report its model ID. SendMessage-resume keeps context but DROPS the model pin; if a follow-up must run on a specific model, spawn a fresh agent with explicit `model=` rather than resuming.

**Enforcement:** only `model=`-pinned spawns actually run the named model (e.g. ultrawork/ralph executor lanes). Session-loop surfaces (deep-interview, inline plan / ralplan / ultragoal / ultrawork) inherit the session model — `/model`-switch before invoking. Unpinned `Task(subagent_type=…)` spawns run OMC's inherit default (not Fable), pinned only by `/team` `roleRouting` in `~/.config/claude-omc/config.jsonc` (planner/architect/critic → `claude-fable-5`), which applies to `/team` spawns only.

### Ralph Workflow: Phase 1 (Define Requirements)

Phase 1 is conversational, not automated. Use Opus for dialogue, Codex for structured outputs.

**Standard Flow**:
1. Describe the project to Claude (Opus)
2. Claude identifies JTBD (Jobs to Be Done) and topics of concern
3. For complex architecture: `/codex-planner high - [describe challenge]`
4. Claude writes `specs/*.md` for each topic
5. Review/refine specs conversationally
6. When ready: `/ralph-check` → `/ralph-plan` → `loop.sh build`

**When to use /codex-planner in Phase 1**:
- Architectural questions surface during discussion
- Multiple valid technical approaches exist
- Novel system or unfamiliar domain
- Security/performance constraints are unclear

**Phase 2/3 (Planning & Building)** are automated via skills:
- `/ralph-plan` - gap analysis, generates IMPLEMENTATION_PLAN.md
- `/ralph-build` - implements one task, validates, commits
- `loop.sh build N` - runs N build iterations with fresh context each

### Verify Your Work
Always find a way to verify changes work:
- Run tests (prefer targeted tests over full suite during iteration)
- Execute the code if possible
- Check linting/type errors
- For UI changes, test in browser/simulator

Verification is the single biggest factor in output quality.

### Incremental Changes
- Make focused, atomic changes
- Commit frequently with clear messages
- Run tests and linting before committing
- Keep PRs reviewable

### Git Worktrees
- Always use `worktrunk` instead of `git worktree` for managing worktrees
- Run `/worktrunk` skill for guidance on configuration and usage

### Semantic Diff And Analysis
- `git diff` is configured globally to use `sem` via an external diff wrapper. Treat plain `git diff` as the default semantic diff view.
- Use `/sem` or `sem impact <entity>` before non-trivial refactors, interface changes, or deletions to estimate blast radius.
- Use `/sem` or `sem blame <file>` when ownership or history matters at the function, method, or class level; prefer it over `git blame` for supported languages.
- Use `/sem` or `sem graph` when mapping dependencies between entities or validating impact-analysis results.
- Use `git diff --no-ext-diff ...` when you need exact line hunks, raw patch context, or behavior on files where semantic parsing is not useful.

## Communication Style

- Be concise and direct
- Skip filler phrases ("Great question!", "I'd be happy to help")
- Have opinions; disagree when appropriate
- Ask for clarification only when truly needed
- Prefer commas, parentheses, periods, or semicolons over em dashes

## Code Standards

### General
- Follow existing patterns in the codebase
- Write self-documenting code
- Include error handling and validation
- Handle errors early with guard clauses
- Parse, don't validate: convert untyped data to typed structures at system boundaries
  (see https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/)

### Type Safety
- Prefer typed structures over untyped containers (e.g., typed objects over raw dicts/maps)
- Use the language's type system to catch errors at compile/lint time
- Treat type annotations as documentation that tooling can verify

### Python
- Black formatting, snake_case naming
- Type hints for all function signatures
- Pydantic models over raw dictionaries
- Absolute imports, grouped: standard / third-party / local
- Google-style docstrings for public functions
- Prefer functional, declarative patterns
- RORO pattern (Receive Object, Return Object)

### TypeScript/JavaScript
- Prettier formatting
- Explicit types over `any`
- Prefer `const` and immutability
- Use async/await over raw promises

## Error Corrections

When I make a mistake, add it here so I don't repeat it:

<!-- 
Example format:
- **Wrong**: Did X when Y was expected
  **Right**: Do Z instead because [reason]
-->

## gstack

Use `/browse` from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

Available skills:
- `/office-hours` - YC Office Hours (startup diagnostic + builder brainstorm)
- `/plan-ceo-review` - CEO/founder-mode plan review
- `/plan-eng-review` - Eng manager-mode plan review
- `/plan-design-review` - Designer's eye plan review
- `/design-consultation` - Design system from scratch
- `/design-shotgun` - Visual design exploration (multiple variants)
- `/design-html` - Production HTML/CSS from approved mockups
- `/review` - Pre-landing PR review
- `/ship` - Ship workflow (tests, review, PR)
- `/land-and-deploy` - Merge, deploy, canary verify
- `/canary` - Post-deploy monitoring
- `/benchmark` - Performance regression detection
- `/browse` - Headless browser for QA and browsing
- `/connect-chrome` - Headed Chrome with side panel
- `/qa` - QA test and fix bugs
- `/qa-only` - QA report only (no fixes)
- `/design-review` - Visual QA and fix
- `/setup-browser-cookies` - Import cookies for authenticated testing
- `/setup-deploy` - Configure deploy settings
- `/retro` - Weekly engineering retrospective
- `/investigate` - Systematic root-cause debugging
- `/document-release` - Post-ship doc updates
- `/codex` - Multi-AI second opinion via Codex CLI
- `/cso` - Security audit (OWASP + STRIDE)
- `/autoplan` - Auto-review pipeline (CEO, design, eng)
- `/careful` - Safety guardrails for destructive commands
- `/freeze` / `/unfreeze` - Scope edits to a directory
- `/guard` - Full safety mode (careful + freeze)
- `/gstack-upgrade` - Upgrade gstack to latest
- `/learn` - Manage project learnings

## Project-Specific Notes

Check for a local `.claude/CLAUDE.md` or `CLAUDE.md` in the repo root for project-specific instructions. Those take precedence over these global defaults.