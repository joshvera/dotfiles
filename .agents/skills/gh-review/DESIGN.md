# Pending GitHub review skill: design

Date: 2026-10-29. Status: v1 built.

## Intent

Reviewing someone else's PR with Claude today is all-or-nothing: `/code-review --comment` posts findings immediately, and anything more careful means hand-writing `gh api` calls. We want a review that builds up while the reviewer reads the code:

1. A Superpowers reviewer drafts findings.
2. The reviewer triages them, one at a time, into a GitHub **pending review** (visible only to them).
3. They keep adding, rewording, moving, and deleting comments as their understanding changes, and can ask "what have I said, and what have I not looked at yet?"
4. They check the result on github.com, then submit or discard it, and only then does the PR author see anything.

## Goals

- Iterate on a pending review across many turns and many Claude sessions without losing state.
- Draft findings with `superpowers:requesting-code-review`, triage them locally, and post only accepted ones.
- A status view: changed files, which are marked Viewed, pending comments per file, and existing threads from other reviewers.
- Edit and move pending comments, not just add them.
- Submit (approve, request changes, comment) or discard, with explicit confirmation.

## Non-goals

- Responding to reviews on your own PR (`superpowers:receiving-code-review` covers that).
- Replying to or resolving other reviewers' threads.
- Reviewing outside GitHub (GitLab, Linear diffs).
- Fully automatic review. A human triages every finding.

## Anti-goals (failures even if it "works")

- Anything reaches the PR author before the user says submit. That includes untriaged findings, `[draft]` markers, and partial reviews.
- Posted comments read like a bot report ("Critical: ..."). Comments are in the user's voice.
- The skill forks or edits the Superpowers plugin files, which would break on the next plugin update.
- A comment silently lands on the wrong line.

## Constraints

- GitHub allows **one pending review per user per PR**. The skill always resumes it and never creates a second.
- Pending comments can have their **body** edited (`updatePullRequestReviewComment`), but their position can't be changed. A move is a delete plus a re-create.
- Line comments must sit on lines inside the PR diff. `subjectType: FILE` allows a file-level comment on any changed file. Anything else goes in the review summary.
- Use the `gh` CLI for GitHub. No GitHub MCP server (user preference).
- The Superpowers reviewer reads local git ranges and must not touch the user's checkout. Fetch the PR head into a ref (`refs/gh-review/pr-<n>`), never check it out in place.
- Confirmed in the GitHub GraphQL schema on 2026-10-29: `addPullRequestReview`, `addPullRequestReviewThread` (`path`, `line`, `side`, `startLine`, `startSide`, `subjectType` LINE|FILE, `pullRequestReviewId`), `updatePullRequestReviewComment`, `deletePullRequestReviewComment`, `updatePullRequestReview`, `submitPullRequestReview`, `deletePullRequestReview`, `markFileAsViewed`, `unmarkFileAsViewed`, and `PullRequestChangedFile.viewerViewedState`.

## Approaches considered

| Approach | Tradeoff | Outcome |
| --- | --- | --- |
| A. `SKILL.md` only; Claude writes GraphQL each time | Smallest, but node IDs, pagination, and diff-line validation are re-derived every call. Token-heavy and prone to the wrong-line bug. | Rejected |
| **B. `SKILL.md` + typed helper CLI** | Exact work (IDs, validation, API calls) is deterministic and testable in the script. Judgment (drafting, rewording, triage) stays in the skill. Costs one script to maintain. | **Chosen by the user** |
| C. Local MCP server | Typed tools, but a long-running process to install per machine, and it cuts against the gh-CLI preference. | Rejected as overkill |

## Workflow

```
 draft ──► triage inbox (local) ──► accept / reword ──► pending review (GitHub)
              │                           │                    │
              └── drop (logged locally)   │      ┌─────────────┤
                                          ▼      ▼             ▼
                                   comment · revise · status · viewed   (loop)
                                                   │
                                   preview on github.com ──► submit | discard
```

Diagram in the conversation: purple steps are Claude-local, teal steps are visible on GitHub (to the user only, until submit).

## The decided parts

### Placement (my call)

- A shared skill; nothing in it is repo-specific.
- Files: `SKILL.md` (workflow and judgment), `scripts/gh_review.py` (helper CLI), `tests/`, and this `DESIGN.md`.
- The PR is passed as a global `--pr` option (URL, `owner/repo#n`, or `n`); it defaults to the current branch's PR.

### Helper CLI: `gh_review.py`

- A single file run with `uv run --script`, dependencies declared inline (PEP 723). Typed models (Pydantic) for PR, review, comment, finding, and file status.
- Talks to GitHub only through `gh api graphql` / `gh api` subprocesses, reusing the user's `gh` auth.
- The PR target is a URL or `owner/repo#n`. It defaults to the current branch's PR via `gh pr view`.
- Every command prints JSON on stdout (for Claude) and a short human summary on stderr. Errors exit non-zero with a message that says what to do.

Subcommands:

| Command | Does |
| --- | --- |
| `open <pr>` | Finds the viewer's PENDING review, or creates one with `addPullRequestReview` (no event). Fetches `refs/pull/<n>/head` into `refs/gh-review/pr-<n>`. Prints review id, the review's commit, head SHA, base SHA, and the PR URL. |
| `status <pr>` | The one read command. Changed files with `viewerViewedState`: unviewed, viewed, or "changed since you viewed it" (GitHub's `DISMISSED`, set when new commits touch a file you'd marked). Your pending comments per file (node ID, line, body). A count of other reviewers' open threads per file. Local inbox counts (untriaged, dropped). A stale warning if the head moved past the inbox's or the review's commit. |
| `add <pr> (--path --line [--start-line] [--side RIGHT] \| --finding <fid>) --body [--file-level]` | Validates the line against the diff (see "Anchoring" below), then creates a thread on the pending review. With `--finding`, takes the position from the inbox finding, runs the snippet check, and removes the finding from the inbox once it's posted. |
| `edit <pr> <comment-id> [--body] [--path --line]` | Body only: `updatePullRequestReviewComment`. Position change: validate, create the new comment, then delete the old one, so a failure never loses the comment. |
| `rm <pr> <comment-id>` | `deletePullRequestReviewComment`. |
| `viewed <pr> <path>... [--unmark]` | `markFileAsViewed` / `unmarkFileAsViewed`, so "I'm done with this file" works from chat. |
| `submit <pr> --event APPROVE\|REQUEST_CHANGES\|COMMENT [--body] --yes` | `submitPullRequestReview`. Refuses without `--yes`. The skill reads the untriaged count from `status` *before* confirming; the count in submit's output is after the fact. |
| `discard <pr> --yes` | `deletePullRequestReview`. Refuses without `--yes`. |
| `findings import <pr> <file>` | Loads reviewer findings (JSON, schema below) into the local inbox and stamps the inbox with the head SHA. |
| `findings drop <pr> <fid> [--reason]` | Marks dropped locally. Never posted. |

Untriaged findings are listed in `status`. There is no separate `findings list`.

### Local findings inbox

- Path: `${XDG_STATE_HOME:-~/.local/state}/gh-review/<owner>/<repo>/<pr>.json`. Outside the repo, so it never gets committed and it is shared across worktrees.
- The file holds one `head_sha` (when the findings were drafted) and a list of findings: `id`, `severity` (critical|important|minor), `path`, `line?`, `start_line?`, `snippet?` (the code text at `line` when drafted), `title`, `what`, `why`, `fix?`, `state` (untriaged|dropped), `drop_reason?`.
- If the head moved since import, `status` warns. The skill offers to re-run the reviewer.
- The inbox is the source of truth only for **untriaged and dropped** findings. A finding that gets posted is removed from the inbox, and from then on GitHub's pending comments are the record. A missing inbox (new machine, deleted file) means "no untriaged findings", and `status` says so explicitly. It does not error.
- Writes are atomic (temp file + rename). No lock: one person reviewing one PR doesn't need one.

### SKILL.md responsibilities (judgment)

1. **Start**: run `open`, then show `status`.
2. **Draft (optional, on request)**: invoke `superpowers:requesting-code-review` by name, filling in base = merge base, head = `refs/gh-review/pr-<n>`, description = PR title and body, and requirements = PR body plus the linked ticket if one is referenced. Add one instruction asking the reviewer to also emit a JSON findings block matching the inbox schema. Save that block and run `findings import`. The reviewer's "Strengths" and verdict are kept in the conversation as suggestions for the submit body and event.
3. **Triage**: present one untriaged finding at a time, most severe first: the finding, the code around it, and a proposed comment in the user's voice. The user says accept, reword (with their direction), drop, or skip. Accept and reword both go through `add --finding`. Findings whose line is not in the diff are offered as file-level comments, or noted for the submit body.
4. **Iterate**: free-form requests map to `add`/`edit`/`rm`/`viewed`. "What's left" and "what have I said" both mean `status`.
5. **Submit / discard**: show the drafted body, the comment count, any untriaged findings still in the inbox, and the suggested event. Always get an explicit yes in chat before `submit` or `discard`, since both are outward-facing or irreversible.

### Tone

Posted comments are short, specific, and in the reviewer's voice. No severity prefixes. Suggestions use GitHub ```` ```suggestion ```` blocks where a concrete fix exists.

## Anchoring

GitHub hasn't been checked on one point: when the PR head has moved past the pending review's commit, does a new thread land on the review's commit or on the head? Validating against the wrong one is exactly how a comment lands on the wrong line.

**v1 rule (no spike run yet):** `open` pins the review to the head commit. Once the head moves past it, `add` and position-changing `edit` refuse. Body edits, `rm`, `viewed`, `submit` and `discard` keep working, and the user submits or discards, then reopens. This is safe whichever way GitHub behaves. Positions are validated against the diff *at the review's commit* (the compare API's `base...commit` diff, identical to `gh pr diff` when head == commit), so a push mid-command can't swap the diff.

**If it chafes**, run the spike: create a pending review on a scratch PR, push a commit that shifts lines, add a thread, and see where it lands. If threads land on the head, relax the refusal to a warning.

Either way, a finding whose `snippet` no longer matches the code at its line is refused and re-located with the user. A comment never lands on a guessed line.

## Calls made after the builder check and advisor review (my calls; check these)

1. **Reviewer line references.** The added reviewer instruction asks for RIGHT-side line numbers at the PR head, a `start_line` for ranges, and the code text at the line as `snippet`. `findings import` accepts anything parseable, with `line` nullable. Validation happens when the finding is posted. A finding with no line, or with a line outside the diff, is offered as a file-level comment if the file changed, otherwise noted for the submit body.
2. **Comment identity.** Commands take the `PullRequestReviewComment` node ID directly. No `c1`/`c2` aliases: aliases based on list position would renumber after a delete and hit the wrong comment. Every thread in a pending review is the viewer's own, so `rm` deletes that one comment.
3. **Repo edge cases.**
   - Always fetch `refs/pull/<n>/head`, which also works for PRs from forks.
   - A pending review that already exists (made in the browser) is adopted as is.
   - Drafting needs a local clone of the PR's repo. Elsewhere, every other command still works through the API.
4. **Confirmation gate.** `submit` and `discard` refuse without `--yes`. `SKILL.md` passes it only after an explicit yes in chat for that specific action.
5. **Cut for v1 (advisor):**
   - `move` and `list` were merged into `edit` and `status`.
   - `findings accept` and `findings list` were folded into `add --finding` and `status`.
   - `summary` was dropped: the body is set at submit. The pending body's visibility in the browser is unverified, so preview-only isn't worth a command.
   - `--force` was dropped: the confirmation shows the untriaged count instead.
   - The PR-author event check was dropped: GitHub's own error is clear.
   - The inbox lock and per-finding `head_sha` were dropped.
6. **Kept against advice:** `viewed`. The advisor suggested deferring it because marking is one click in the browser. But "I'm done with this file" from chat is the staging area you asked for, and it's one mutation.

## Testing (for the builder)

- Unit tests on the pure parts: diff-hunk line validation (multi-hunk, deleted lines, LEFT vs RIGHT, renamed files), snippet mismatch refusal, the inbox state machine, stale detection, the `--yes` gate, and finding-JSON parsing including malformed input.
- GitHub calls go through one thin `gh` runner, so tests substitute that boundary only, with recorded GraphQL responses. State in the test report that live GitHub behavior is unverified by unit tests.
- One manual end-to-end run on a real PR the user picks: open, import findings, accept one via `add --finding`, edit its body, move it with `edit --line`, mark a file viewed, view on github.com, discard (not submit), then confirm nothing was published.

## Left to the builder

- Exact GraphQL query shapes and pagination (comments over 100, files over 100).
- How the reviewer's JSON block is delimited inside its prose output.
- Wording of the human summary lines on stderr.
- Whether `edit --path` (moving a comment to another file) needs extra validation beyond the hunk check.

## Changes after the independent code review (2026-10-29)

- `add --finding` without `--line` now refuses when the inbox was drafted at a different commit than the review, or when the finding has no snippet. Snippets must match the whole line (whitespace-insensitive), not a substring.
- `findings import` stamps the commit the reviewer read (`refs/gh-review/pr-<n>`, or `--head-sha`), not the head at import time.
- Moves keep the comment's original side (read from its thread's `diffSide`). A range comment must be given a new `--start-line`. `status` shows each comment's side.
- The diff is fetched at the review's commit, not the live head.
- Re-import keeps dropped findings and never reuses ids. `start_line == line` is normalized to single-line.
- File, JSON, and validation errors come back as the JSON error contract, not tracebacks.
