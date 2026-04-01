# Global Agent Rules

## Testing and Validation
- Never mock by default.
- Always use live fixtures, real databases, and real integrations whenever they are available and practical.
- Mocking is permitted only as an absolute last resort, and only for components that cannot be accessed in the current environment.

## Semantic Diff And Analysis
- `git diff` is configured globally to use `sem` via an external diff wrapper. Treat plain `git diff` as the default semantic diff view.
- Use `sem impact <entity>` before non-trivial refactors, interface changes, or deletions to estimate blast radius.
- Use `sem blame <file>` when ownership or history matters at the function, method, or class level; prefer it over `git blame` for supported languages.
- Use `sem graph` when mapping dependencies between entities or validating impact-analysis results.
- Use `git diff --no-ext-diff ...` when you need exact line hunks, raw patch context, or behavior on files where semantic parsing is not useful.
