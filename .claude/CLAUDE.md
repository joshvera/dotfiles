# Claude Global Configuration

Shared, agent-agnostic guidance (also read by Codex). Edit it there, not here:

@~/.codex/AGENTS.md

The sections below are Claude-specific.

## Workflow Principles

### Plan First
Start complex tasks in Plan mode (shift+tab twice). Iterate on the plan until it's solid before switching to auto-accept edits. A good plan dramatically improves outcomes.

### Subagent Model Routing

Extends superpowers' **Model Selection** (subagent-driven-development): use the least powerful model that can do the role, and **always pass `model=` explicitly** — an omitted model silently inherits the session's most expensive one. Tiers, cheapest first:

- **Haiku** — mechanical work: 1–2 files with a complete spec, tests/docs, mechanical refactor, isolated low-blast-radius fixes (the plan already contains the code → transcription).
- **Sonnet (default)** — integration and judgment: multi-file coordination, debugging, standard implementation, and per-task review passes inside a run. Default for parallel executor lanes. Turn count beats token price, so Sonnet is the *floor* for reviewers and for implementers working from prose. **Run Sonnet at `effort: high` at most.** Past high it costs more than Opus for less (Artificial Analysis, 2026-11: Sonnet max scores 55 at ~$10/task and 34 min; Opus high 52 at $3.46 and 9 min; Opus medium 48 at $2.45), so never raise Sonnet's effort; move to Opus at medium instead. Decide before spawning, because a reviewer that missed something does not know it: use Opus when the work touches shared-core risk (auth, persistence, concurrency, migrations), covers a whole PR or branch, or has no check the agent can run (a test, a build, a script). After spawning, move a Sonnet lane to Opus on an observable signal only: it returns BLOCKED, it reports a claim it could not verify by running something, or the same check fails twice.
- **Opus (`effort: high`)** — architecture/design, the adversarial critic, and any whole-branch review, which includes reviewing a full PR (e.g. `/gh-review` drafting findings). Promote exactly ONE "spine" executor lane to Opus when the task has shared-core risk (auth, persistence, concurrency, migrations, cross-cutting state).
- **Fable** — only where judgment concentrates in a *decision*: requirements interviews, and first-pass planning on genuinely large/ambiguous work. ~2× Opus ($10/$50 per MTok) — spend it only where it shapes the whole run. **Never default Fable on review loops, executor lanes, or security review.**

A re-review that only verifies fixes to an already-reviewed plan or diff runs on **Opus at `effort: medium`** in a fresh agent, or **Opus at `effort: high`** when the fix touches shared-core risk (auth, persistence, concurrency, migrations). First reviews and the adversarial critic stay on Opus at high.

Escalate a tier when a subagent returns BLOCKED. Keep **security review on Sonnet/Opus, never Fable** — its cybersecurity classifiers can refuse legitimate security analysis.

**Mechanics (verified 2026-07-01):** "(inherit)" does NOT track the session model — an inherit-spawned planner self-reported `claude-opus-4-8[1m]` while the session ran Fable 5. Pin `model=` and verify by asking the agent to self-report its model ID. SendMessage-resume keeps context but DROPS the model pin; if a follow-up must run on a specific model, spawn a fresh agent with explicit `model=` rather than resuming.

**Enforcement:** only `model=`-pinned spawns actually run the named model. Work done inline in the main loop runs on the session model, so `/model`-switch before starting it.

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

### Semantic Diff And Analysis
- The shared guidance covers `sem`; in Claude, the `/sem` skill wraps it.

## Communication Style

- Be concise and direct
- Skip filler phrases ("Great question!", "I'd be happy to help")
- Have opinions; disagree when appropriate
- Ask for clarification only when truly needed

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
