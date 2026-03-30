# GitHub Workflow For Qodo Threads

Use this reference only when the `qodo-pr-resolver` skill triggers.

## Branch To PR Lookup

```bash
branch="$(git branch --show-current)"
gh pr list --head "$branch" --state open --json number,title,url,headRefName
```

## Review Thread State Query

Use this to decide whether a Qodo issue has a live inline discussion anchor. Do not use it alone to decide whether the underlying finding is fixed.

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes {
          isResolved
          isOutdated
          path
          line
          startLine
          comments(first:20) {
            nodes {
              id
              databaseId
              author { login }
              body
              url
              createdAt
            }
          }
        }
      }
    }
  }
}' -F owner=<owner> -F repo=<repo> -F number=<pr-number>
```

## Comment Sources

- PR-level summary comments:
  - GitHub MCP `github_fetch_issue_comments`
- Inline review comments:
  - GitHub MCP `github_fetch_pr_comments`

Use summary comments to build the persistent-review audit trail and to enrich inline issues with:
- exact title
- severity framing
- evidence
- agent prompt

Use inline review comments to get:
- exact discussion anchor
- file path and line location
- current thread state via GraphQL
- whether a finding is `live` or `outdated`

## Qodo Author Matching

Treat these as Qodo identities:
- `qodo-code-review`
- `qodo-code-review[bot]`
- `qodo-merge[bot]`
- `qodo-ai[bot]`
- `pr-agent-pro`
- `pr-agent-pro-staging`

## Source Precedence

- The persistent review summary is the canonical unresolved finding list.
- GitHub review-thread state decides whether a finding has a live inline discussion anchor.
- Current code/tests decide whether the finding is actually fixed.
- The refreshed persistent review decides whether Qodo has acknowledged the fix on the current PR head.

## Attachment States

### `live-inline`

A finding is `live-inline` only if all of the following are true:
- the inline thread author matches a Qodo identity
- `isResolved` is `false`
- `isOutdated` is `false`

These are the only findings with exact inline discussion anchors.

### `outdated-inline`

A finding is `outdated-inline` if the persistent review still carries it, but the only matching inline thread is outdated.

### `summary-only`

A finding is `summary-only` if it is unresolved in the persistent review summary and has no matching live inline thread.

Do not drop `outdated-inline` or `summary-only` items without code/test evidence.

## Deduping Rule

1. Match summary and inline entries by exact Qodo title.
2. If multiple inline threads share the title, prefer a live thread over an outdated one.
3. Prefer inline data for file path, line range, anchor ID, URL, and thread state.
4. Prefer summary data for severity, evidence, and the agent prompt.
5. If the title is missing in one source, use file path plus line range as the fallback key.

## State Axes

For each unresolved finding, classify:

- `evidence_state`
  - `unresolved`
  - `fixed`
  - `ambiguous`
- `qodo_state`
  - `current`
  - `needs_refresh`
  - `persisted_after_refresh`
  - `acknowledged`

Recommended action mapping:
- `evidence_state=unresolved` -> `Fix`
- `evidence_state=fixed` + `qodo_state=needs_refresh` -> `Refresh Qodo`
- `evidence_state=fixed` + `qodo_state=persisted_after_refresh` -> `Ask Qodo`
- `evidence_state=fixed` + `qodo_state=acknowledged` -> `Verified fixed`
- `evidence_state=ambiguous` -> `Ask Qodo`

## Inline Reply Commands

Prefer GitHub MCP `github_reply_to_review_comment`.

Use these only when the user explicitly wants a reviewer-facing breadcrumb. Do not treat inline replies as a documented Qodo control surface.

Fallback:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number>/comments/<comment-id>/replies \
  -X POST \
  -f body='Fixed - sanitized NaN greeks before JSON serialization'
```

## Manual Review Trigger

Use this when local evidence says a finding is fixed, but the current persistent review still carries it, and the branch is fully pushed while Qodo is idle:

```text
/agentic_review
```

## Acknowledgment Workflow

1. Build the canonical finding list from the current persistent review.
2. Run the local evidence pass.
3. If `evidence_state=fixed` and the finding is still present, mark `qodo_state=needs_refresh`.
4. Request `/agentic_review`.
5. Re-fetch the persistent review after the new review finishes.
6. If the finding disappears or is reflected as resolved, mark `qodo_state=acknowledged`.
7. If the finding still appears, mark `qodo_state=persisted_after_refresh` and use `/ask`.

Do not call a finding stale or historical based only on `isOutdated=true`.

## Ambiguity Or Disagreement Fallback

When a finding cannot be proven fixed from current code and tests, or when it persists after refresh despite evidence, ask Qodo directly on the PR or affected lines:

```text
/ask Is the finding "<exact title>" still relevant on the current PR head? The current code at <file:line> now does <brief behavior>, and <test-or-check> supports that, but the persistent review still carries the finding after /agentic_review.
```
