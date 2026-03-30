# Claude Global Configuration

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

## Project-Specific Notes

Check for a local `.claude/CLAUDE.md` or `CLAUDE.md` in the repo root for project-specific instructions. Those take precedence over these global defaults.
