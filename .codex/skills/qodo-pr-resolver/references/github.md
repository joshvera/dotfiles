# GitHub Workflow For Qodo Threads

Use this reference only when the `qodo-pr-resolver` skill triggers.

## Branch To PR Lookup

```bash
branch="$(git branch --show-current)"
gh pr list --head "$branch" --state open --json number,title,url,headRefName
```

## Review Thread State Query

Use this to decide whether a Qodo issue is still actionable.

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

Use summary comments to enrich a live inline issue with:
- exact title
- severity framing
- evidence
- agent prompt

Use inline review comments to get:
- exact reply target
- file path and line location
- current thread state via GraphQL

## Qodo Author Matching

Treat these as Qodo identities:
- `qodo-code-review`
- `qodo-code-review[bot]`
- `qodo-merge[bot]`
- `qodo-ai[bot]`
- `pr-agent-pro`
- `pr-agent-pro-staging`

## Live-Issue Filter

An issue is actionable only if all of the following are true:
- the inline thread author matches a Qodo identity
- `isResolved` is `false`
- `isOutdated` is `false`

If the persistent summary still mentions the issue but the inline thread is resolved or outdated, treat it as stale history and do not show it as actionable.

## Deduping Rule

1. Match summary and inline entries by exact Qodo title.
2. Prefer inline data for file path, line range, reply ID, and URL.
3. Prefer summary data for severity, evidence, and the agent prompt.
4. If the title is missing in one source, use file path plus line range as the fallback key.

## Reply Commands

Prefer GitHub MCP `github_reply_to_review_comment`.

Fallback:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number>/comments/<comment-id>/replies \
  -X POST \
  -f body='Fixed — sanitized NaN greeks before JSON serialization'
```

## Manual Review Trigger

Use this to request a fresh Qodo review when the branch is fully pushed and Qodo is idle:

```text
/agentic_review
```
