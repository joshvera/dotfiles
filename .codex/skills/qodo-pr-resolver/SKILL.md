---
name: qodo-pr-resolver
description: Review live Qodo findings on the open GitHub pull request for the current branch. Use GitHub review-thread state to distinguish live findings from stale persistent-summary entries, then fix or defer the actionable Qodo issues and reply on the exact inline thread.
metadata:
  short-description: Resolve live Qodo PR findings
---

# Qodo PR Resolver

Use this skill when the user asks about Qodo findings, wants to know which Qodo comments are still live, or wants help fixing or replying to Qodo review issues on a GitHub PR.

This skill is GitHub-first. Prefer GitHub MCP tools for PR metadata and comments, and use `gh api graphql` only for review-thread state (`isResolved`, `isOutdated`) or branch-to-PR lookup if MCP is insufficient.

## Current-Head Rule

Treat the persistent Qodo summary comment as an index, not as the source of truth.

An issue is actionable only when its inline GitHub review thread is both:
- `isResolved == false`
- `isOutdated == false`

Do not dismiss a finding as stale solely because the persistent summary still mentions it. Qodo keeps resolved findings visible in its audit trail and persistent review summary.

## When To Use

- The user asks "what Qodo issues are left?" or "is this Qodo comment stale?"
- The user wants to fix Qodo comments or reply to them.
- The user wants to request a fresh Qodo review on a PR.

## Workflow

### 1. Check push state first

- Run `git status --short`, `git branch --show-current`, and `git rev-list --left-right --count @{upstream}...HEAD`.
- If there are uncommitted changes, tell the user they are not part of Qodo's latest review.
- If there are unpushed commits, tell the user Qodo has not reviewed them yet. Offer to push first instead of triaging stale feedback.

### 2. Find the open PR for the current branch

- Prefer GitHub MCP when it can identify the PR cleanly.
- Fallback:
  - `branch=$(git branch --show-current)`
  - `gh pr list --head "$branch" --state open --json number,title,url,headRefName`
- If there is no open PR, stop and say there is nothing for Qodo to review yet.

### 3. Fetch three views of Qodo feedback

- PR-level comments:
  - Use GitHub MCP `github_fetch_issue_comments` for the PR number.
- Inline review comments:
  - Use GitHub MCP `github_fetch_pr_comments`.
- Review-thread state:
  - Use the GitHub GraphQL query in [references/github.md](./references/github.md) via `gh api graphql`.

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

### 5. Build the live issue list

- Start from inline review threads, not from the persistent summary.
- Keep only threads with `isResolved=false` and `isOutdated=false`.
- For each live thread, preserve:
  - exact Qodo title
  - file path and line range
  - inline comment database ID and URL
  - thread body text
- Then merge in matching summary-comment data by exact title:
  - severity framing
  - issue type
  - evidence
  - agent prompt

Deduplicate by exact Qodo title first. If needed, use file path plus line range as a secondary key.

### 6. Present only actionable issues

Keep Qodo's original ordering. Do not rename titles.

Display a compact table with:
- number
- exact Qodo title
- severity
- type
- location
- action (`Fix` or `Defer`)

Exclude:
- resolved threads
- outdated threads
- summary-only items without a live inline thread

### 7. Fix or defer using the Qodo prompt

When the user wants to address an item:
- Read the relevant files.
- Follow Qodo's agent prompt unless it is clearly stale relative to current code.
- If the prompt is stale, say exactly what is stale before proposing the updated fix.
- After the user approves the change, implement it and run targeted verification.

### 8. Reply on the exact inline comment

Reply to the preserved inline review comment, not just the summary comment.

Prefer GitHub MCP `github_reply_to_review_comment`. Fallback `gh api` reply commands are in [references/github.md](./references/github.md).

Reply format:
- Fixed: `Fixed — <brief description of the change>`
- Deferred: `Deferred — <brief reason>`

Optionally post a short PR-level summary comment after a batch, but do not use that as a substitute for inline replies.

### 9. Request a fresh Qodo review when needed

Prefer `/agentic_review` for a new manual Qodo review. Treat `/review` as a repo-specific legacy alias only if it is already known to work in that repository.

Only request a new review when:
- the branch is fully pushed
- there is an open PR
- Qodo is not already processing the PR

## Notes

- Qodo's persistent summary is useful for titles, evidence, and prompts, but it is not the authority for whether an item is still live.
- GitHub review-thread state is the authority for stale versus actionable.
- If there are no live Qodo threads, say so explicitly instead of paraphrasing stale summary items.
