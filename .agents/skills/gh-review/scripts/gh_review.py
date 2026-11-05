#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["pydantic>=2.7"]
# ///
"""Stage a GitHub pending review: comment, revise, track coverage, then submit.

Every command prints JSON on stdout (for the agent) and a one-line summary on
stderr (for the human). Nothing here is visible to the PR author until
`submit --yes`.

    findings import ──► inbox (local) ──► add --finding ──► pending review (GitHub)
                          │                                   │
                          └─► findings drop      add · edit · rm · viewed · status
                                                              │
                                                  submit --yes | discard --yes
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from collections.abc import Callable
from dataclasses import dataclass, field
from enum import StrEnum
from pathlib import Path
from typing import Generic, Literal, Protocol, Self, TypeVar

try:
    from pydantic import BaseModel, ConfigDict, TypeAdapter, ValidationError, field_validator, model_validator
    from pydantic.alias_generators import to_camel
except ModuleNotFoundError:
    sys.exit("gh_review.py needs uv for its dependencies: `brew install uv`, then run the script directly, not via python3.")

Side = Literal["LEFT", "RIGHT"]
Json = dict[str, object]


class ReviewError(Exception):
    """A failure the user can act on. The message says what to do next."""


def note(message: str) -> None:
    print(message, file=sys.stderr)


# ── GitHub boundary ──────────────────────────────────────────────────────────


class Runner(Protocol):
    def __call__(self, args: list[str], stdin: str | None = None) -> str: ...


def run_gh(args: list[str], stdin: str | None = None) -> str:
    try:
        proc = subprocess.run(["gh", *args], input=stdin, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        raise ReviewError("`gh` is not installed: `brew install gh`, then `gh auth login`.") from None
    if proc.returncode != 0:
        raise ReviewError(f"`gh {' '.join(args[:2])}` failed: {proc.stderr.strip()}")
    return proc.stdout


@dataclass(frozen=True)
class GitHub:
    run: Runner = run_gh

    def graphql(self, query: str, **variables: object) -> Json:
        body = json.dumps({"query": query, "variables": variables})
        payload = json.loads(self.run(["api", "graphql", "--method", "POST", "--input", "-"], body))
        if errors := payload.get("errors"):
            raise ReviewError("; ".join(str(error.get("message")) for error in errors))
        return payload["data"]

    def diff_at(self, pr: PrRef, base: str, commit: str) -> str:
        """The PR diff as of `commit` (same three-dot diff `gh pr diff` shows), so a push mid-command can't swap it.

        The diff is parsed, never echoed raw, so escape sequences in it (which gh refuses by default) are fine.
        """
        endpoint = f"repos/{pr.slug}/compare/{base}...{commit}"
        return self.run(["api", endpoint, "-H", "Accept: application/vnd.github.diff", "--allow-escape-sequences"])


def dig(value: object, *keys: str | int) -> object:
    """Walk a GraphQL response, failing loudly if GitHub's shape isn't what we asked for."""
    for key in keys:
        # Separate branches so the type checker narrows list vs dict indexing.
        if isinstance(key, int) and isinstance(value, list) and len(value) > key:  # noqa: SIM114
            value = value[key]
        elif isinstance(key, str) and isinstance(value, dict) and value.get(key) is not None:
            value = value[key]
        else:
            raise ReviewError(f"Unexpected GitHub response: missing {'.'.join(map(str, keys))}")
    return value


class GqlModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


T = TypeVar("T")


class PageInfo(GqlModel):
    has_next_page: bool = False
    end_cursor: str | None = None


class Connection(GqlModel, Generic[T]):
    nodes: list[T]
    page_info: PageInfo = PageInfo()


class Login(GqlModel):
    login: str


class CommitRef(GqlModel):
    oid: str


class PendingComment(GqlModel):
    id: str
    path: str
    line: int | None = None
    start_line: int | None = None
    body: str
    outdated: bool = False


class Review(GqlModel):
    id: str
    author: Login | None = None
    commit: CommitRef | None = None
    comments: Connection[PendingComment]


class PullRequest(GqlModel):
    id: str
    url: str
    head_ref_oid: str
    base_ref_name: str
    reviews: Connection[Review]


CONTEXT_QUERY = """
query($owner: String!, $repo: String!, $number: Int!) {
  viewer { login }
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      id url headRefOid baseRefName
      reviews(states: PENDING, first: 20) {
        nodes {
          id author { login } commit { oid }
          comments(first: 100) {
            pageInfo { hasNextPage }
            nodes { id path line startLine body outdated }
          }
        }
      }
    }
  }
}
"""


@dataclass(frozen=True)
class PrRef:
    owner: str
    repo: str
    number: int

    @property
    def slug(self) -> str:
        return f"{self.owner}/{self.repo}"


@dataclass(frozen=True)
class Context:
    pr: PrRef
    viewer: str
    pull: PullRequest
    review: Review | None

    def require_review(self) -> Review:
        if self.review is None:
            raise ReviewError("No pending review on this PR. Run `open` first.")
        return self.review

    @property
    def head_moved(self) -> bool:
        return self.review is not None and self.review.commit is not None and self.review.commit.oid != self.pull.head_ref_oid

    def require_current_head(self) -> Review:
        """Line comments are blocked once the head moves: they could anchor to the review's older commit."""
        review = self.require_review()
        if review.commit is not None and self.head_moved:
            raise ReviewError(
                f"The PR head moved since this pending review started (review at {review.commit.oid[:8]}, "
                f"head at {self.pull.head_ref_oid[:8]}). Adding or moving line comments is blocked so nothing "
                "lands on the wrong line. Body edits, rm, viewed, submit and discard still work; to review the "
                "new head, submit or discard this review and run `open` again."
            )
        return review


def load_context(gh: GitHub, pr: PrRef) -> Context:
    data = gh.graphql(CONTEXT_QUERY, owner=pr.owner, repo=pr.repo, number=pr.number)
    try:
        raw_pull = dig(data, "repository", "pullRequest")
    except ReviewError:
        raise ReviewError(f"PR {pr.slug}#{pr.number} not found, or `gh` can't see it.") from None
    viewer = Login.model_validate(dig(data, "viewer")).login
    pull = PullRequest.model_validate(raw_pull)
    mine = [r for r in pull.reviews.nodes if r.author is not None and r.author.login == viewer]
    review = mine[0] if mine else None
    if review is not None and review.comments.page_info.has_next_page:
        note("warning: over 100 pending comments; only the first 100 are shown")
    return Context(pr=pr, viewer=viewer, pull=pull, review=review)


# ── PR references ────────────────────────────────────────────────────────────

PR_URL = re.compile(r"github\.com/([^/\s]+)/([^/\s]+)/pull/(\d+)")
PR_SHORT = re.compile(r"^([\w.-]+)/([\w.-]+)#(\d+)$")
PR_NUMBER = re.compile(r"^#?(\d+)$")


def parse_pr(value: str | None, gh: GitHub) -> PrRef:
    """Accept a PR URL, `owner/repo#n`, `n` (current repo), or nothing (current branch's PR)."""
    if value is None:
        value = gh.run(["pr", "view", "--json", "url", "--jq", ".url"]).strip()
    if match := PR_URL.search(value) or PR_SHORT.match(value):
        return PrRef(match[1], match[2], int(match[3]))
    if match := PR_NUMBER.match(value):
        slug = gh.run(["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]).strip()
        owner, repo = slug.split("/", 1)
        return PrRef(owner, repo, int(match[1]))
    raise ReviewError(f"Can't read PR reference {value!r}. Use a URL, owner/repo#123, or 123.")


# ── Diff positions ───────────────────────────────────────────────────────────

HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")


@dataclass
class FileDiff:
    """Commentable lines per side: line number -> (hunk index, code text)."""

    path: str
    right: dict[int, tuple[int, str]] = field(default_factory=dict)
    left: dict[int, tuple[int, str]] = field(default_factory=dict)

    def lines(self, side: Side) -> dict[int, tuple[int, str]]:
        return self.right if side == "RIGHT" else self.left


def parse_diff(text: str) -> dict[str, FileDiff]:
    files: dict[str, FileDiff] = {}
    current: FileDiff | None = None
    hunk = -1
    old = new = old_left = new_left = 0
    for raw in text.splitlines():
        # Inside a hunk, count lines instead of sniffing prefixes: a removed
        # "-- comment" line reads as "--- comment" and would pass for a header.
        if current is not None and (old_left > 0 or new_left > 0):
            tag, code = raw[:1], raw[1:]
            if tag == "\\":
                continue
            if tag == "-":
                current.left[old] = (hunk, code)
                old, old_left = old + 1, old_left - 1
            elif tag == "+":
                current.right[new] = (hunk, code)
                new, new_left = new + 1, new_left - 1
            else:
                current.left[old] = (hunk, code)
                current.right[new] = (hunk, code)
                old, new, old_left, new_left = old + 1, new + 1, old_left - 1, new_left - 1
            continue
        if raw.startswith("diff --git "):
            # The header names every file, including empty, binary, and pure-rename ones with no hunks.
            path = raw.rsplit(" b/", 1)[-1]
            current = files.setdefault(path, FileDiff(path))
        elif (match := HUNK.match(raw)) and current is not None:
            hunk += 1
            old, new = int(match[1]), int(match[3])
            old_left = int(match[2]) if match[2] is not None else 1
            new_left = int(match[4]) if match[4] is not None else 1
    return files


def describe_ranges(lines: dict[int, tuple[int, str]]) -> str:
    spans: list[list[int]] = []
    for number in sorted(lines):
        if spans and number == spans[-1][1] + 1 and lines[number][0] == lines[spans[-1][1]][0]:
            spans[-1][1] = number
        else:
            spans.append([number, number])
    return ", ".join(f"{a}" if a == b else f"{a}-{b}" for a, b in spans) or "none"


def check_position(diff: dict[str, FileDiff], path: str, line: int, start_line: int | None, side: Side) -> str:
    """Return the code at `line`, or explain why GitHub would reject the position."""
    file = diff.get(path)
    if file is None:
        raise ReviewError(f"{path} isn't changed in this PR, so it can't take a line comment.")
    lines = file.lines(side)
    if line not in lines:
        raise ReviewError(f"{path}:{line} ({side}) is outside the diff. Commentable lines: {describe_ranges(lines)}.")
    if start_line is not None:
        if start_line >= line:
            raise ReviewError(f"start line {start_line} must come before line {line}.")
        if start_line not in lines or lines[start_line][0] != lines[line][0]:
            raise ReviewError(f"{path}:{start_line}-{line} must sit inside a single diff hunk.")
    return lines[line][1]


def snippet_matches(snippet: str, code: str) -> bool:
    """Whole-line match, whitespace-insensitive. Substrings would let `end` match `append(x)`."""
    wanted = " ".join(snippet.split())
    return bool(wanted) and wanted == " ".join(code.split())


# ── Local findings inbox ─────────────────────────────────────────────────────


class Severity(StrEnum):
    CRITICAL = "critical"
    IMPORTANT = "important"
    MINOR = "minor"


class FindingState(StrEnum):
    UNTRIAGED = "untriaged"
    DROPPED = "dropped"


class FindingDraft(BaseModel):
    """What the reviewer emits. Extra keys are ignored so reviewer drift doesn't break import."""

    model_config = ConfigDict(extra="ignore")

    severity: Severity
    path: str
    line: int | None = None
    start_line: int | None = None
    snippet: str | None = None
    title: str
    what: str
    why: str
    fix: str | None = None

    @field_validator("severity", mode="before")
    @classmethod
    def lowercase_severity(cls, value: object) -> object:
        return value.lower() if isinstance(value, str) else value

    @model_validator(mode="after")
    def single_line_range(self) -> Self:
        if self.start_line is not None and self.start_line == self.line:
            self.start_line = None
        return self


class Finding(FindingDraft):
    id: str
    state: FindingState = FindingState.UNTRIAGED
    drop_reason: str | None = None


class Inbox(BaseModel):
    pr: str
    head_sha: str
    findings: list[Finding]

    def find(self, finding_id: str) -> Finding:
        for finding in self.findings:
            if finding.id == finding_id:
                if finding.state is not FindingState.UNTRIAGED:
                    raise ReviewError(f"Finding {finding_id} was already dropped.")
                return finding
        raise ReviewError(f"No finding {finding_id} in the inbox. Run `status` to see what's left.")

    @property
    def untriaged(self) -> list[Finding]:
        return [f for f in self.findings if f.state is FindingState.UNTRIAGED]


SEVERITY_ORDER = {Severity.CRITICAL: 0, Severity.IMPORTANT: 1, Severity.MINOR: 2}
DRAFTS = TypeAdapter(list[FindingDraft])


def inbox_path(pr: PrRef) -> Path:
    root = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
    return root / "gh-review" / pr.owner / pr.repo / f"{pr.number}.json"


def load_inbox(pr: PrRef) -> Inbox | None:
    path = inbox_path(pr)
    return Inbox.model_validate_json(path.read_text()) if path.exists() else None


def save_inbox(pr: PrRef, inbox: Inbox) -> None:
    path = inbox_path(pr)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False, suffix=".tmp") as tmp:
        tmp.write(inbox.model_dump_json(indent=2))
    os.replace(tmp.name, path)


# ── Mutations ────────────────────────────────────────────────────────────────

ADD_REVIEW = """
mutation($pullRequestId: ID!, $commitOID: GitObjectID!) {
  addPullRequestReview(input: {pullRequestId: $pullRequestId, commitOID: $commitOID}) {
    pullRequestReview { id }
  }
}
"""

ADD_THREAD = """
mutation($input: AddPullRequestReviewThreadInput!) {
  addPullRequestReviewThread(input: $input) { thread { comments(first: 1) { nodes { id } } } }
}
"""

COMMENT_NODE = """
query($id: ID!) {
  node(id: $id) {
    ... on PullRequestReviewComment { id path line startLine body pullRequestReview { id } }
  }
}
"""


class NodeId(GqlModel):
    id: str


class CommentNode(GqlModel):
    id: str
    path: str
    line: int | None = None
    start_line: int | None = None
    body: str
    pull_request_review: NodeId | None = None


def pending_comment(gh: GitHub, review: Review, comment_id: str) -> CommentNode:
    """Fetch a comment, refusing anything outside the pending review: editing a published one is outward-facing."""
    try:
        comment = CommentNode.model_validate(dig(gh.graphql(COMMENT_NODE, id=comment_id), "node"))
    except (ReviewError, ValidationError):
        raise ReviewError(f"No pending review comment {comment_id}. Run `status` for current ids.") from None
    if comment.pull_request_review is None or comment.pull_request_review.id != review.id:
        raise ReviewError(f"Comment {comment_id} isn't in your pending review; this tool only edits unpublished comments.")
    return comment


def parse_side(value: str | None) -> Side | None:
    return "LEFT" if value == "LEFT" else "RIGHT" if value == "RIGHT" else None


def single_line(start_line: int | None, line: int | None) -> int | None:
    """GitHub wants no start line for a one-line comment, so `--start-line N --line N` means single-line."""
    return None if start_line == line else start_line


@dataclass(frozen=True)
class Position:
    path: str
    line: int | None
    start_line: int | None
    side: Side


def post_thread(gh: GitHub, review: Review, position: Position, body: str) -> str:
    payload: Json = {"pullRequestReviewId": review.id, "path": position.path, "body": body}
    if position.line is None:
        payload["subjectType"] = "FILE"
    else:
        payload |= {"subjectType": "LINE", "line": position.line, "side": position.side}
        if position.start_line is not None:
            payload |= {"startLine": position.start_line, "startSide": position.side}
    data = gh.graphql(ADD_THREAD, input=payload)
    return str(dig(data, "addPullRequestReviewThread", "thread", "comments", "nodes", 0, "id"))


def validate(gh: GitHub, ctx: Context, review: Review, position: Position) -> str | None:
    """Check a position against the diff at the review's commit; returns the code at the line (None for file-level)."""
    commit = review.commit.oid if review.commit else ctx.pull.head_ref_oid
    diff = parse_diff(gh.diff_at(ctx.pr, ctx.pull.base_ref_name, commit))
    if position.line is None:
        if position.path not in diff:
            raise ReviewError(f"{position.path} isn't changed in this PR, so it can't take a file comment.")
        return None
    return check_position(diff, position.path, position.line, position.start_line, position.side)


# ── Commands ─────────────────────────────────────────────────────────────────


def cmd_open(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    ctx = load_context(gh, pr)
    created = ctx.review is None
    if created:
        gh.graphql(ADD_REVIEW, pullRequestId=ctx.pull.id, commitOID=ctx.pull.head_ref_oid)
        ctx = load_context(gh, pr)
    review = ctx.require_review()
    refs = fetch_refs(pr, ctx.pull)
    note(f"{'created' if created else 'resumed'} pending review on {ctx.pull.url}")
    if ctx.head_moved:
        note("warning: the PR head moved since this review started; line comments are blocked")
    if refs is None:
        note("note: no git remote here matches this PR's repo, so drafting findings is unavailable")
    return {
        "url": ctx.pull.url,
        "review_id": review.id,
        "created": created,
        "review_commit": review.commit.oid if review.commit else None,
        "head": ctx.pull.head_ref_oid,
        "head_moved": ctx.head_moved,
        "pending_comments": len(review.comments.nodes),
        "local_refs": refs,
    }


FILES_QUERY = """
query($owner: String!, $repo: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      files(first: 100, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes { path viewerViewedState }
      }
    }
  }
}
"""

THREADS_QUERY = """
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        pageInfo { hasNextPage }
        nodes { path isResolved diffSide comments(first: 1) { nodes { id author { login } } } }
      }
    }
  }
}
"""


class ChangedFile(GqlModel):
    path: str
    viewer_viewed_state: Literal["VIEWED", "UNVIEWED", "DISMISSED"]


class ThreadComment(GqlModel):
    id: str
    author: Login | None = None


class Thread(GqlModel):
    """Side lives on the thread, not the comment, so moves and `status` read it from here."""

    path: str
    is_resolved: bool
    diff_side: Side | None = None
    comments: Connection[ThreadComment]

    @property
    def first(self) -> ThreadComment | None:
        return self.comments.nodes[0] if self.comments.nodes else None


def review_threads(gh: GitHub, pr: PrRef) -> list[Thread]:
    data = gh.graphql(THREADS_QUERY, owner=pr.owner, repo=pr.repo, number=pr.number)
    threads = Connection[Thread].model_validate(dig(data, "repository", "pullRequest", "reviewThreads"))
    if threads.page_info.has_next_page:
        note("warning: over 100 review threads; other reviewers' counts and comment sides are partial")
    return threads.nodes


VIEWED_LABEL = {"VIEWED": "viewed", "UNVIEWED": "unviewed", "DISMISSED": "changed_since_viewed"}


def changed_files(gh: GitHub, pr: PrRef) -> list[ChangedFile]:
    files: list[ChangedFile] = []
    after: str | None = None
    while True:
        data = gh.graphql(FILES_QUERY, owner=pr.owner, repo=pr.repo, number=pr.number, after=after)
        page = Connection[ChangedFile].model_validate(dig(data, "repository", "pullRequest", "files"))
        files.extend(page.nodes)
        if not page.page_info.has_next_page:
            return files
        after = page.page_info.end_cursor


def cmd_status(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    ctx = load_context(gh, pr)
    others: dict[str, int] = {}
    sides: dict[str, Side | None] = {}
    for thread in review_threads(gh, pr):
        first = thread.first
        if first is None:
            continue
        sides[first.id] = thread.diff_side
        if not thread.is_resolved and first.author is not None and first.author.login != ctx.viewer:
            others[thread.path] = others.get(thread.path, 0) + 1

    mine = ctx.review.comments.nodes if ctx.review else []
    files = []
    for changed in changed_files(gh, pr):
        comments = [c.model_dump(exclude={"path"}) | {"side": sides.get(c.id)} for c in mine if c.path == changed.path]
        files.append(
            {
                "path": changed.path,
                "viewed": VIEWED_LABEL[changed.viewer_viewed_state],
                "my_comments": comments,
                "others_open_threads": others.get(changed.path, 0),
            }
        )

    inbox = load_inbox(pr)
    untriaged = sorted(inbox.untriaged, key=lambda f: SEVERITY_ORDER[f.severity]) if inbox else []
    inbox_out: Json | None = None
    if inbox is not None:
        inbox_out = {
            "stale": inbox.head_sha != ctx.pull.head_ref_oid,
            "untriaged": [f.model_dump(exclude={"state", "drop_reason"}) for f in untriaged],
            "dropped": sum(f.state is FindingState.DROPPED for f in inbox.findings),
        }
    viewed = sum(f["viewed"] == "viewed" for f in files)
    note(
        f"{viewed}/{len(files)} files viewed · {len(mine)} pending comments · "
        f"{len(untriaged)} untriaged findings" + ("" if inbox else " (no local inbox)")
    )
    return {
        "url": ctx.pull.url,
        "review": None
        if ctx.review is None
        else {"id": ctx.review.id, "commit": ctx.review.commit.oid if ctx.review.commit else None, "head_moved": ctx.head_moved},
        "files": files,
        "inbox": inbox_out,
    }


def cmd_add(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    ctx = load_context(gh, pr)
    review = ctx.require_current_head()
    inbox = load_inbox(pr) if args.finding else None
    if args.finding and inbox is None:
        raise ReviewError("No local findings inbox for this PR. Import findings first.")
    finding = inbox.find(args.finding) if inbox else None

    path = args.path or (finding.path if finding else None)
    if path is None:
        raise ReviewError("Pass --path (or --finding).")
    # A finding's own line is only trusted if it was drafted at this commit and its snippet still matches.
    # An explicit --line is the user re-locating it, so neither guard applies.
    trust_finding_line = finding is not None and args.line is None and not args.file_level
    if args.file_level:
        line, start_line = None, None
    elif finding is not None and trust_finding_line:
        line, start_line = finding.line, finding.start_line
        if inbox is not None and review.commit is not None and inbox.head_sha != review.commit.oid:
            raise ReviewError(
                f"Finding {finding.id} was drafted at {inbox.head_sha[:8]}, but the review is at "
                f"{review.commit.oid[:8]}, so its line number may point at different code. "
                "Re-locate it with --line, or re-draft findings."
            )
        if line is not None and not finding.snippet:
            raise ReviewError(f"Finding {finding.id} has no snippet to confirm its line. Check the code and pass --line.")
    else:
        line, start_line = args.line, args.start_line
    if line is None and not args.file_level:
        raise ReviewError("No line to anchor to. Pass --line, or --file-level for a comment on the whole file.")

    position = Position(path, line, single_line(start_line, line), parse_side(args.side) or "RIGHT")
    code = validate(gh, ctx, review, position)
    snippet = finding.snippet if trust_finding_line and finding is not None else None
    if snippet and code is not None and not snippet_matches(snippet, code):
        raise ReviewError(
            f"The code at {path}:{line} no longer matches finding {args.finding} "
            f"(expected {snippet.strip()!r}, found {code.strip()!r}). Re-locate it with --line."
        )
    comment_id = post_thread(gh, review, position, args.body)
    if inbox is not None and finding is not None:
        inbox.findings.remove(finding)
        save_inbox(pr, inbox)
    where = f"{path}:{line}" if line is not None else f"{path} (file)"
    note(f"added pending comment on {where}")
    return {"comment_id": comment_id, "path": path, "line": line, "start_line": start_line, "finding": args.finding}


DELETE_COMMENT = """
mutation($id: ID!) { deletePullRequestReviewComment(input: {id: $id}) { clientMutationId } }
"""

UPDATE_COMMENT = """
mutation($id: ID!, $body: String!) {
  updatePullRequestReviewComment(input: {pullRequestReviewCommentId: $id, body: $body}) { clientMutationId }
}
"""


def cmd_edit(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    moving = args.line is not None or args.path is not None
    if not moving and args.body is None:
        raise ReviewError("Nothing to change. Pass --body, or --line/--path to move the comment.")
    ctx = load_context(gh, pr)
    review = ctx.require_current_head() if moving else ctx.require_review()
    comment = pending_comment(gh, review, args.comment_id)
    if not moving:
        gh.graphql(UPDATE_COMMENT, id=comment.id, body=args.body)
        note(f"edited {comment.path}:{comment.line}")
        return {"comment_id": comment.id, "moved": False}

    if args.line is None:
        raise ReviewError("Moving to another file needs --line too.")
    if comment.start_line is not None and args.start_line is None:
        raise ReviewError(
            f"This comment spans lines {comment.start_line}-{comment.line}. Pass --start-line for the new range "
            "(the same as --line to make it a single-line comment)."
        )
    # Keep the comment on its original side unless told otherwise: moving a note on a removed line
    # must not quietly re-anchor it to the added side.
    side: Side | None = parse_side(args.side) or next(
        (t.diff_side for t in review_threads(gh, pr) if t.first and t.first.id == comment.id), None
    )
    if side is None:
        raise ReviewError("Couldn't tell which side of the diff this comment is on. Pass --side RIGHT or --side LEFT.")
    position = Position(args.path or comment.path, args.line, single_line(args.start_line, args.line), side)
    validate(gh, ctx, review, position)
    # Create before delete so a failure never loses the comment.
    new_id = post_thread(gh, review, position, args.body or comment.body)
    gh.graphql(DELETE_COMMENT, id=comment.id)
    note(f"moved comment to {position.path}:{position.line}")
    return {"comment_id": new_id, "replaced": comment.id, "moved": True, "path": position.path, "line": position.line}


def cmd_rm(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    review = load_context(gh, pr).require_review()
    comment = pending_comment(gh, review, args.comment_id)
    gh.graphql(DELETE_COMMENT, id=comment.id)
    note(f"deleted pending comment on {comment.path}:{comment.line}")
    return {"deleted": comment.id}


MARK_VIEWED = """
mutation($pullRequestId: ID!, $path: String!) {
  markFileAsViewed(input: {pullRequestId: $pullRequestId, path: $path}) { clientMutationId }
}
"""

UNMARK_VIEWED = """
mutation($pullRequestId: ID!, $path: String!) {
  unmarkFileAsViewed(input: {pullRequestId: $pullRequestId, path: $path}) { clientMutationId }
}
"""


def cmd_viewed(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    ctx = load_context(gh, pr)
    mutation = UNMARK_VIEWED if args.unmark else MARK_VIEWED
    for path in args.paths:
        gh.graphql(mutation, pullRequestId=ctx.pull.id, path=path)
    note(f"{'unmarked' if args.unmark else 'marked'} {len(args.paths)} file(s) as viewed")
    return {"paths": args.paths, "viewed": not args.unmark}


SUBMIT = """
mutation($id: ID!, $event: PullRequestReviewEvent!, $body: String) {
  submitPullRequestReview(input: {pullRequestReviewId: $id, event: $event, body: $body}) {
    pullRequestReview { url state }
  }
}
"""

DISCARD = """
mutation($id: ID!) { deletePullRequestReview(input: {pullRequestReviewId: $id}) { clientMutationId } }
"""


def cmd_submit(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    review = load_context(gh, pr).require_review()
    inbox = load_inbox(pr)
    data = gh.graphql(SUBMIT, id=review.id, event=args.event, body=args.body)
    url = str(dig(data, "submitPullRequestReview", "pullRequestReview", "url"))
    note(f"submitted review ({args.event}): {url}")
    return {"url": url, "event": args.event, "untriaged_left": len(inbox.untriaged) if inbox else 0}


def cmd_discard(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    review = load_context(gh, pr).require_review()
    gh.graphql(DISCARD, id=review.id)
    note("discarded the pending review (the local findings inbox is kept)")
    return {"discarded": review.id}


def cmd_findings_import(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    raw = sys.stdin.read() if args.file == "-" else Path(args.file).read_text()
    try:
        drafts = DRAFTS.validate_json(raw)
    except ValidationError as error:
        raise ReviewError(f"Findings JSON doesn't match the schema:\n{error}") from error
    # Stamp the commit the reviewer actually read, not whatever the head is now: the author may have pushed mid-review.
    head = args.head_sha or run_git("rev-parse", "--verify", "--quiet", f"refs/gh-review/pr-{pr.number}")
    if not head:
        raise ReviewError("Can't tell which commit these findings were drafted at. Run `open` here, or pass --head-sha.")
    previous = load_inbox(pr)
    # Untriaged findings are replaced; the drop log survives, and ids keep counting so an old id never
    # silently points at a new finding.
    kept = [f for f in previous.findings if f.state is FindingState.DROPPED] if previous else []
    start = max((int(f.id.removeprefix("f")) for f in previous.findings), default=0) + 1 if previous else 1
    findings = [Finding(id=f"f{i}", **draft.model_dump()) for i, draft in enumerate(drafts, start=start)]
    save_inbox(pr, Inbox(pr=f"{pr.slug}#{pr.number}", head_sha=head, findings=kept + findings))
    if previous is not None:
        note(f"replaced {len(previous.untriaged)} untriaged findings; kept {len(kept)} dropped")
    note(f"imported {len(findings)} findings at {head[:8]}")
    return {"imported": [f.id for f in findings], "head_sha": head, "inbox": str(inbox_path(pr))}


def cmd_findings_drop(gh: GitHub, pr: PrRef, args: argparse.Namespace) -> Json:
    inbox = load_inbox(pr)
    if inbox is None:
        raise ReviewError("No local findings inbox for this PR.")
    finding = inbox.find(args.finding_id)
    finding.state, finding.drop_reason = FindingState.DROPPED, args.reason
    save_inbox(pr, inbox)
    note(f"dropped {finding.id}: {finding.title}")
    return {"dropped": finding.id, "untriaged_left": len(inbox.untriaged)}


# ── Local git refs (for the reviewer) ────────────────────────────────────────


def run_git(*args: str) -> str | None:
    proc = subprocess.run(["git", *args], capture_output=True, text=True, check=False)
    return proc.stdout.strip() if proc.returncode == 0 else None


def fetch_refs(pr: PrRef, pull: PullRequest) -> Json | None:
    """Fetch the PR head and base into refs/gh-review/* so a reviewer can diff without touching the checkout."""
    remotes = run_git("remote", "-v") or ""
    pattern = re.compile(rf"[:/]{re.escape(pr.owner)}/{re.escape(pr.repo)}(\.git)?$", re.IGNORECASE)
    remote = next((line.split()[0] for line in remotes.splitlines() if pattern.search(line.split()[1])), None)
    if remote is None:
        return None
    head_ref, base_ref = f"refs/gh-review/pr-{pr.number}", f"refs/gh-review/pr-{pr.number}-base"
    if (
        run_git(
            "fetch", "--quiet", remote, f"+refs/pull/{pr.number}/head:{head_ref}", f"+refs/heads/{pull.base_ref_name}:{base_ref}"
        )
        is None
    ):
        note(f"warning: `git fetch {remote}` failed; drafting findings is unavailable")
        return None
    return {"head_ref": head_ref, "base_ref": base_ref, "merge_base": run_git("merge-base", base_ref, head_ref)}


# ── CLI ──────────────────────────────────────────────────────────────────────

Handler = Callable[[GitHub, PrRef, argparse.Namespace], Json]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="gh_review", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--pr", help="PR URL, owner/repo#n, or n. Defaults to the current branch's PR.")
    sub = parser.add_subparsers(dest="command", required=True)

    def command(name: str, handler: Handler, help: str) -> argparse.ArgumentParser:
        cmd = sub.add_parser(name, help=help)
        cmd.set_defaults(handler=handler)
        return cmd

    def position_args(cmd: argparse.ArgumentParser) -> None:
        cmd.add_argument("--path")
        cmd.add_argument("--line", type=int)
        cmd.add_argument("--start-line", type=int, help="first line of a multi-line comment")
        cmd.add_argument(
            "--side",
            choices=["RIGHT", "LEFT"],
            help="LEFT for removed lines. Default: RIGHT for add, the original side for a move",
        )

    command("open", cmd_open, "resume or create your pending review")
    command("status", cmd_status, "files, viewed state, your comments, other threads, untriaged findings")

    add = command("add", cmd_add, "add a comment to the pending review")
    position_args(add)
    add.add_argument("--finding", help="post an inbox finding (takes its position unless --line is given)")
    add.add_argument("--file-level", action="store_true", help="comment on the whole file")
    add.add_argument("--body", required=True)

    edit = command("edit", cmd_edit, "change a pending comment's body or position")
    edit.add_argument("comment_id")
    position_args(edit)
    edit.add_argument("--body")

    rm = command("rm", cmd_rm, "delete a pending comment")
    rm.add_argument("comment_id")

    viewed = command("viewed", cmd_viewed, "mark files viewed (or --unmark)")
    viewed.add_argument("paths", nargs="+")
    viewed.add_argument("--unmark", action="store_true")

    submit = command("submit", cmd_submit, "publish the review (needs --yes)")
    submit.add_argument("--event", choices=["APPROVE", "REQUEST_CHANGES", "COMMENT"], required=True)
    submit.add_argument("--body")
    submit.add_argument("--yes", action="store_true")

    discard = command("discard", cmd_discard, "delete the pending review (needs --yes)")
    discard.add_argument("--yes", action="store_true")

    findings = sub.add_parser("findings", help="local inbox of reviewer findings")
    findings_sub = findings.add_subparsers(dest="findings_command", required=True)
    imp = findings_sub.add_parser("import", help="replace the inbox with reviewer findings (JSON array; - for stdin)")
    imp.set_defaults(handler=cmd_findings_import)
    imp.add_argument("file")
    imp.add_argument("--head-sha", help="commit the findings were drafted at (default: refs/gh-review/pr-<n> from `open`)")
    drop = findings_sub.add_parser("drop", help="drop a finding without posting it")
    drop.set_defaults(handler=cmd_findings_drop)
    drop.add_argument("finding_id")
    drop.add_argument("--reason")
    return parser


def main(argv: list[str] | None = None, gh: GitHub | None = None) -> int:
    args = build_parser().parse_args(argv)
    gh = gh or GitHub()
    try:
        # Checked before anything touches GitHub: submit and discard are the outward-facing ones.
        if getattr(args, "yes", True) is False:
            raise ReviewError(f"Refusing to {args.command} without --yes. Confirm with the user first.")
        result = args.handler(gh, parse_pr(args.pr, gh), args)
    except (ReviewError, ValidationError, OSError, json.JSONDecodeError) as error:
        print(json.dumps({"error": str(error)}))
        note(f"error: {error}")
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
