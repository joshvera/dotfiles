---
name: qodo-pr-resolver
description: Review Qodo findings on the open GitHub pull request for the current branch using the persistent review as the canonical finding list and GitHub inline threads as reply targets, then fix, verify, refresh, or defer them with evidence and Qodo acknowledgment state.
metadata:
  short-description: Resolve Qodo PR findings with evidence
---

# Qodo PR Resolver

Use this skill when the user asks about Qodo findings, wants to know which comments are still live, wants help fixing or replying to Qodo review issues on a GitHub PR, or wants to verify whether outdated or summary-only Qodo findings were actually addressed.

This skill is GitHub-first. Prefer GitHub MCP tools for PR metadata and comments, and use `gh api graphql` only for review-thread state (`isResolved`, `isOutdated`) or branch-to-PR lookup if MCP is insufficient.

Use the `qodoDocs` MCP server only for Qodo product behavior, such as:
- persistent review comments
- findings visibility and collapse behavior
- PR history / relevance
- `/ask` workflow

Do not use `qodoDocs` as the source of live PR state.

## Source Precedence

- GitHub review-thread state decides whether a finding has a live inline reply target.
- Current code, tests, and targeted verification decide whether a finding is actually fixed.
- The current persistent review decides whether Qodo still carries the finding on the current PR head.
- Qodo persistent review provides the full audit trail: titles, ordering, severity, evidence, prompts, and findings that may be hidden, collapsed, outdated, or summary-only.
- PR History / Relevance is advisory, not dispositive.

## Canonical Finding Rule

- Treat the persistent review as the canonical unresolved finding list for the current PR head.
- Treat GitHub inline review threads as attachment metadata:
  - a live inline thread gives you an exact reply target
  - an outdated inline thread tells you prior placement, not current resolution
- `isOutdated=true` is not enough to call a finding fixed. It only means the original inline attachment no longer maps cleanly to the current diff.
- Do not call a finding `stale` or `historical` until current code/test evidence and refreshed Qodo state both support that disposition.

## Status Axes

- Track `evidence_state` separately from `qodo_state`.
- `evidence_state`:
  - `unresolved`
  - `fixed`
  - `ambiguous`
- `qodo_state`:
  - `current`: Qodo currently carries the finding and local evidence does not yet prove it fixed
  - `needs_refresh`: local evidence says it is fixed, but the current persistent review still carries it
  - `persisted_after_refresh`: local evidence says it is fixed and Qodo still carries it after `/agentic_review`
  - `acknowledged`: Qodo no longer carries it after refresh, or otherwise reflects that the finding was resolved

## When To Use

- The user asks "what Qodo issues are left?" or "is this Qodo comment stale?"
- The user wants to fix Qodo comments or reply to them.
- The user wants to know whether outdated or summary-only Qodo findings were actually addressed.
- The user wants to request a fresh Qodo review on a PR.

## Workflow

### 1. Check push state first

- Run `git status --short`, `git branch --show-current`, and `git rev-list --left-right --count @{upstream}...HEAD`.
- If `@{upstream}` is missing, report that the current branch has no upstream configured and compare local `HEAD` to the PR head SHA after you find the PR.
- If there are uncommitted changes, tell the user they are not part of Qodo's latest review.
- If there are unpushed commits, tell the user Qodo has not reviewed them yet. Offer to push first instead of triaging stale feedback.

### 2. Find the open PR for the current branch

- Prefer GitHub MCP when it can identify the PR cleanly.
- Fallback:
  - `branch=$(git branch --show-current)`
  - `gh pr list --head "$branch" --state open --json number,title,url,headRefName`
- If there is no open PR, stop and say there is nothing for Qodo to review yet.

### 3. Fetch four views of Qodo feedback

- PR-level comments:
  - Use GitHub MCP `github_fetch_issue_comments` for the PR number.
- Inline review comments:
  - Use GitHub MCP `github_fetch_pr_comments`.
- Review-thread state:
  - Use the GitHub GraphQL query in [references/github.md](./references/github.md) via `gh api graphql`.
- Persistent review summary:
  - Identify the latest Qodo persistent review comment and use it as the audit-trail backlog, not just as enrichment for live threads.

Filter to Qodo authors only. Match at least:
- `qodo-code-review`
- `qodo-code-review[bot]`
- `qodo-merge[bot]`
- `qodo-ai[bot]`
- `pr-agent-pro`
- `pr-agent-pro-staging`

### 4. Check whether Qodo is still running

If any recent Qodo summary or PR-level comment says the review is still in progress, for example:
- `Come back again in a few minutes`
- `An AI review agent is analysing this pull request`

then stop and tell the user to wait for the review to finish.

### 5. Build one normalized finding list

- Start from unresolved findings in the persistent review summary / audit trail.
- Match inline review threads by exact Qodo title first. If the title is missing in one source, use file path plus line range as the fallback key.
- For each finding, preserve:
  - exact Qodo title
  - severity framing
  - issue type
  - file path and line range
  - evidence
  - agent prompt
  - `source_state`: `live-inline`, `outdated-inline`, or `summary-only`
  - `reply_target`: inline comment database ID and URL only when a live inline thread exists

Do not assume collapsed or hidden findings are irrelevant; Qodo can hide additional findings in the summary UI without discarding them.

### 6. Run one evidence pass before dismissing anything

- Inspect current code at the cited location.
- Inspect relevant tests or adjacent coverage.
- Run targeted verification when needed.
- Assign each finding an `evidence_state`:
  - `unresolved`
  - `fixed`
  - `ambiguous`

Do not collapse `fixed` into "done" yet. A local fix and a Qodo-acknowledged fix are separate states.

The important rule is: verification is required before dismissal, but it does not need to be a separate queue or a second standalone triage phase.

### 7. Track Qodo acknowledgment separately

- Start with the current persistent review as the source of Qodo's current position.
- If `evidence_state=unresolved`, set `qodo_state=current`.
- If `evidence_state=fixed` and the current persistent review still carries the finding, set `qodo_state=needs_refresh`.
- If you request `/agentic_review` and the refreshed persistent review still carries the finding, set `qodo_state=persisted_after_refresh`.
- If you request `/agentic_review` and the finding disappears from the refreshed persistent review or is otherwise reflected as resolved, set `qodo_state=acknowledged`.
- If you have not refreshed Qodo yet, do not upgrade `needs_refresh` to `acknowledged`.

Recommended action mapping:
- `reply_target` present + `evidence_state=unresolved` -> `Fix` or `Defer`
- no `reply_target` + `evidence_state=unresolved` -> `Fix`
- `evidence_state=fixed` + `qodo_state=needs_refresh` -> `Refresh Qodo`
- `evidence_state=fixed` + `qodo_state=persisted_after_refresh` -> `Ask Qodo`
- `evidence_state=fixed` + `qodo_state=acknowledged` -> `Verified fixed`
- `evidence_state=ambiguous` -> `Ask Qodo`
- `Ignore as historical` only when current code, repo history, and refreshed Qodo state all support that disposition and the user wants it

### 8. Evidence-fixed but not yet acknowledged

- If a live inline reply target exists, reply there with the evidence-backed fix summary.
- Do not call the finding stale yet just because the inline thread is outdated or the code now looks correct.
- If the branch is fully pushed and Qodo is idle, request `/agentic_review`.
- Re-fetch the persistent review after the refresh finishes.
- If the finding remains after refresh, ask a targeted `/ask` question with:
  - the exact Qodo title
  - the current file and line reference
  - the specific code or test evidence that now appears to address it
- Only downgrade the finding to historical/stale after the refreshed review or `/ask` response makes that clear.

### 9. Present one table

Keep Qodo's original ordering. Do not rename titles.

Display one compact table with:
- number
- exact Qodo title
- `source_state` (`live-inline`, `outdated-inline`, `summary-only`)
- `evidence_state` (`unresolved`, `fixed`, `ambiguous`) when known
- `qodo_state` (`current`, `needs_refresh`, `persisted_after_refresh`, `acknowledged`) when known
- severity
- type
- location
- reply target (`inline` or `none`)
- action (`Fix`, `Refresh Qodo`, `Ask Qodo`, `Verified fixed`, `Ignore as historical`)

If helpful, add a one-line summary above the table:
- how many items have live inline reply targets
- how many remain summary-only or outdated

### 10. Fix or defer using the Qodo prompt

When the user wants to address an item:
- Read the relevant files.
- Follow Qodo's agent prompt unless it is clearly stale relative to current code.
- If the prompt is stale, say exactly what is stale before proposing the updated fix.
- After the user approves the change, implement it and run targeted verification.

For findings without a live reply target:
- keep the evidence in your response
- do not pretend there is an inline thread to reply to
- optionally post a PR-level summary comment only if the user asks for it

### 11. Reply on the exact inline comment

Reply only to preserved live inline review comments, not just the summary comment.

Prefer GitHub MCP `github_reply_to_review_comment`. Fallback `gh api` reply commands are in [references/github.md](./references/github.md).

Reply format:
- Fixed: `Fixed - <brief description of the change>`
- Deferred: `Deferred - <brief reason>`

Do not reply inline to summary-only findings unless a matching live inline comment exists.

### 12. Ask Qodo when the evidence is ambiguous or Qodo still disagrees

If code and tests do not cleanly prove whether a finding is resolved:
- recommend a targeted `/ask` comment on the PR or on the specific diff lines
- keep the finding marked `ambiguous` until the ambiguity is resolved

If code and tests do prove a finding is fixed, but it still persists after `/agentic_review`:
- keep `evidence_state=fixed`
- set `qodo_state=persisted_after_refresh`
- use `/ask` with the exact title and current evidence

`/ask` is additional context, not a replacement for code and test verification or for refreshing the persistent review first.

### 13. Request a fresh Qodo review when needed

Prefer `/agentic_review` for a new manual Qodo review. Treat `/review` as a repo-specific legacy alias only if it is already known to work in that repository.

Only request a new review when:
- the branch is fully pushed
- there is an open PR
- Qodo is not already processing the PR

Use `/agentic_review` by default when a finding is `evidence_state=fixed` but `qodo_state=needs_refresh`.

## Notes

- Qodo's persistent review is an audit trail across commits, not just a convenience summary.
- GitHub review-thread state is the authority for live reply targets, not for whether the underlying concern was actually fixed.
- Findings can remain relevant even when the original inline thread is outdated or collapsed in the summary UI.
- A finding is only fully clear when both local evidence and refreshed Qodo state agree.
- When Qodo product behavior is unclear, use the `qodoDocs` MCP server to check the official docs before guessing.
