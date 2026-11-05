---
name: gh-review
description: Review someone else's GitHub PR as a pending review that builds up while the user reads. Optionally draft findings with a reviewer subagent, triage them one at a time, then add, reword, move, or delete comments, track which files are covered, preview on github.com, and submit only on the user's say-so. Use when the user wants to review a PR, start or resume a pending review, triage review findings, or asks what they've commented on or have left to review.
---

# GitHub pending review

A pending review on GitHub is visible only to its author until it's submitted. This skill uses one as a staging area. The user reads the PR, you shape comments with them, they check the result on github.com, and nothing reaches the PR author until they say submit.

All GitHub work goes through `gh_review.py`. Run it directly, not via `python3`: its shebang uses `uv run --script` to fetch its one dependency. It needs `uv` and `gh` and reuses the user's `gh` login. Every command prints JSON on stdout and a one-line summary on stderr. Pass `--pr <url | owner/repo#n | n>` before the subcommand, or omit it to use the current branch's PR.

```sh
"${CLAUDE_PLUGIN_ROOT}/skills/gh-review/scripts/gh_review.py" --pr owner/repo#123 status
```

`CLAUDE_PLUGIN_ROOT` is set when the skill arrives through the plugin; if it is unset, the script is at `scripts/gh_review.py` next to this file. The examples below shorten the path to `gh_review.py`.

## Rules

- **Never run `submit` or `discard` without an explicit yes in chat for that specific action.** Before asking, show the event, the summary body, the pending comment count, and any untriaged findings. Only then pass `--yes`. A yes to one submit doesn't cover a later one.
- Untriaged findings stay local. Only post a finding after the user accepts or rewords it.
- Comments are written in the user's voice: short, specific, no severity prefixes ("Critical:"), no reviewer boilerplate. Where there's a concrete fix, use a GitHub ```` ```suggestion ```` block.
- If a command fails, relay its error message. They say what to do next. Don't retry with guessed line numbers.

## 1. Start

Run `open`. It resumes the user's pending review or creates one, and fetches the PR into `refs/gh-review/pr-<n>` (head) and `refs/gh-review/pr-<n>-base`. Then run `status` and give a short picture: files changed, how many are viewed, the user's pending comments, other reviewers' open threads, and untriaged findings.

If `open` reports `head_moved`, tell the user: line comments are blocked on this review because new comments could anchor to the old commit. Body edits, `rm`, `viewed`, `submit` and `discard` still work. To review the new head, they submit or discard and `open` again.

## 2. Draft findings (only when the user asks)

Needs `local_refs` from `open`, which means the current repo is a clone of the PR's repo. If it's null, say drafting isn't available here and continue without it.

Follow `superpowers:requesting-code-review` to dispatch its reviewer subagent, filling the placeholders like this:

- `DESCRIPTION`: the PR title and body (`gh pr view <n> --json title,body`).
- `PLAN_OR_REQUIREMENTS`: the PR body plus the linked ticket, if one is referenced.
- `BASE_SHA`: `local_refs.merge_base`.
- `HEAD_SHA`: `local_refs.head_ref`.

Append this to the reviewer's prompt, unchanged:

> After your normal report, add one fenced code block tagged `gh-review-findings` holding a JSON array with one object per issue: `severity` ("critical" | "important" | "minor"), `path` (repo-relative), `line` (line number in the head version, or null if not tied to a line), `start_line` (first line for a range, else null), `snippet` (the exact code text on `line`, trimmed; null if no line), `title`, `what`, `why`, `fix` (or null). Use head-version line numbers. Do not include strengths or recommendations in this block.

The skill's "act on feedback" section doesn't apply: you're reviewing someone else's code, not fixing your own. If that skill isn't installed, dispatch any read-only reviewer subagent with the same inputs and the appended block.

Save the JSON block to a scratch file and run `findings import <file>`. It stamps the findings with the commit the reviewer read (`refs/gh-review/pr-<n>`, so run it in the same clone after `open`). Re-importing replaces untriaged findings but keeps the drop log, and new findings get fresh ids. Keep the reviewer's strengths and verdict in mind as suggestions for the submit body and event; don't post them.

## 3. Triage

Go through untriaged findings from `status`, most severe first, **one at a time**. For each, show:

- the finding in a sentence or two,
- the code around it (read it from `refs/gh-review/pr-<n>`, e.g. `git show refs/gh-review/pr-<n>:<path>`),
- a proposed comment in the user's voice.

Then ask the user to accept, reword, drop, or skip it.

- **Accept or reword:** `add --finding <id> --body "<comment>"`. The position comes from the finding.
- **The CLI refuses the finding's own line:** that happens when the snippet no longer matches the code, when the finding has no snippet, or when it was drafted at a different commit than the review. Show the user the code, agree on the right line, then `add --finding <id> --line <n> --body ...`. An explicit `--line` is the user's call, so those checks are skipped.
- **Line outside the diff:** offer `add --finding <id> --file-level --body ...` if the file changed, otherwise note it for the submit body.
- **Drop:** `findings drop <id> --reason "<why>"`.
- **Skip:** leave it untriaged and move on.

If `status` shows the inbox as `stale` (the head moved since drafting), say so and offer to re-draft. Until then, every finding needs a confirmed `--line`.

## 4. Iterate

Map the user's requests while they read:

| User says | Run |
| --- | --- |
| "comment on line 40 that ..." | `add --path <p> --line 40 --body ...` (add `--start-line` for a range, `--side LEFT` for removed lines) |
| "reword that comment" | `edit <comment-id> --body ...` |
| "move it to line 52" | `edit <comment-id> --line 52`. Creates the new comment, then deletes the old. Keeps the original side. A range comment needs `--start-line` (equal to `--line` to make it single-line) |
| "delete that one" | `rm <comment-id>` |
| "I'm done with this file" / "unmark it" | `viewed <path>` / `viewed <path> --unmark` |
| "what have I said?" / "what's left?" | `status` |

Comment IDs and sides come from `status` (`files[].my_comments[]`). Look them up fresh after any change, since moving a comment gives it a new ID.

In `status`, `changed_since_viewed` means new commits touched a file after the user marked it viewed. Call those out.

## 5. Preview and finish

When the user thinks they're done, point them at the PR URL: the pending comments show on github.com for them alone. Then draft a short summary body and propose an event (`APPROVE`, `REQUEST_CHANGES`, or `COMMENT`), informed by the reviewer's verdict if there was one.

Ask for explicit confirmation, showing the event, the body, the comment count, and any untriaged findings left. On yes:

```
gh_review.py --pr <pr> submit --event REQUEST_CHANGES --body "<summary>" --yes
```

Or, if they want to throw it away: confirm, then `discard --yes`. The local inbox survives a discard.

## Files

- `scripts/gh_review.py`: the helper CLI. `--help` on any subcommand lists its flags.
- `tests/`: unit tests, with GitHub faked at the `gh` boundary: `uv run --with pytest --with 'pydantic>=2.7' pytest tests` from this skill's directory.
- `DESIGN.md`: why it's built this way, and what was cut for v1.
- The findings inbox lives at `${XDG_STATE_HOME:-~/.local/state}/gh-review/<owner>/<repo>/<n>.json`.
