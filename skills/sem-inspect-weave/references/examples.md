# Examples

## Interpreting sem output

If `sem diff` shows:

- function authUser modified
- function validateToken added

Then conclude:

- the authentication flow changed
- prioritize review for security implications
- use `inspect` next to rank risk and blast radius

## When to run weave

Run `weave` only when merge/coordination concerns exist (branch integration, conflicts, multi-agent overlap). Do not run weave as a routine review step.
