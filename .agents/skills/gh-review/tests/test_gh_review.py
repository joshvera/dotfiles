"""Tests for gh_review. GitHub is faked at the `gh` subprocess boundary only.

Run from the skill directory: uv run --with pytest --with 'pydantic>=2.7' pytest tests
Live GitHub behavior (anchoring, permissions) is not covered here.
"""

import json
import sys
from pathlib import Path
from typing import Any

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import gh_review
from gh_review import GitHub, PrRef, ReviewError, check_position, parse_diff, snippet_matches

PR = PrRef("o", "r", 7)

DIFF = """\
diff --git a/app/models/user.rb b/app/models/user.rb
index 111..222 100644
--- a/app/models/user.rb
+++ b/app/models/user.rb
@@ -10,3 +10,4 @@ class User
   def name
-    @name
+    @name.strip
+    # trailing
   end
@@ -40,2 +41,3 @@ class User
   def x
+    y
   end
diff --git a/db/x.sql b/db/x.sql
--- a/db/x.sql
+++ b/db/x.sql
@@ -1,2 +1,1 @@
--- old comment
 select 1;
\\ No newline at end of file
diff --git a/old.rb b/old.rb
deleted file mode 100644
--- a/old.rb
+++ /dev/null
@@ -1 +0,0 @@
-gone
diff --git a/a.rb b/b.rb
similarity index 100%
rename from a.rb
rename to b.rb
diff --git a/static/.nojekyll b/static/.nojekyll
new file mode 100644
index 0000000..e69de29
"""


# ── Diff parsing and positions ───────────────────────────────────────────────


def test_parse_diff_numbers_both_sides_across_hunks():
    user = parse_diff(DIFF)["app/models/user.rb"]
    assert user.right[11] == (0, "    @name.strip")
    assert user.right[13] == (0, "  end")
    assert user.left[11] == (0, "    @name")
    assert user.right[42] == (1, "    y")
    assert 14 not in user.right


def test_removed_line_starting_with_dashes_is_not_read_as_a_file_header():
    files = parse_diff(DIFF)
    assert files["db/x.sql"].left[1] == (2, "-- old comment")
    assert files["db/x.sql"].right[1] == (2, "select 1;")
    assert not any("old comment" in path for path in files)


def test_deleted_renamed_and_empty_files_are_known_to_the_diff():
    files = parse_diff(DIFF)
    assert files["old.rb"].left[1] == (3, "gone")
    assert "b.rb" in files and "a.rb" not in files
    assert "static/.nojekyll" in files


def test_line_outside_the_diff_is_rejected_with_the_commentable_ranges():
    with pytest.raises(ReviewError, match=r"outside the diff\. Commentable lines: 10-13, 41-43"):
        check_position(parse_diff(DIFF), "app/models/user.rb", 20, None, "RIGHT")


def test_multi_line_comment_must_stay_inside_one_hunk():
    diff = parse_diff(DIFF)
    assert check_position(diff, "app/models/user.rb", 12, 11, "RIGHT") == "    # trailing"
    with pytest.raises(ReviewError, match="single diff hunk"):
        check_position(diff, "app/models/user.rb", 42, 12, "RIGHT")


def test_left_side_addresses_removed_lines():
    assert check_position(parse_diff(DIFF), "app/models/user.rb", 11, None, "LEFT") == "    @name"


def test_unchanged_file_is_rejected():
    with pytest.raises(ReviewError, match="isn't changed"):
        check_position(parse_diff(DIFF), "README.md", 1, None, "RIGHT")


def test_snippet_match_ignores_whitespace_but_not_content():
    assert snippet_matches("@name.strip", "    @name.strip  ")
    assert not snippet_matches("@name.downcase", "    @name.strip")
    assert not snippet_matches("end", "    append(x)")
    assert not snippet_matches("   ", "anything")


# ── Fake GitHub ──────────────────────────────────────────────────────────────

MUTATIONS = (
    "addPullRequestReviewThread",
    "deletePullRequestReviewComment",
    "updatePullRequestReviewComment",
    "submitPullRequestReview",
)


class FakeGh:
    """Answers the handful of `gh` calls the CLI makes; anything else fails the test."""

    def __init__(self, head: str = "h1", review_commit: str = "h1", c1_side: str = "RIGHT", c1_start_line: int | None = None):
        self.head, self.review_commit = head, review_commit
        self.c1_side, self.c1_start_line = c1_side, c1_start_line
        self.calls: list[list[str]] = []
        self.mutations: list[tuple[str, dict[str, Any]]] = []

    def __call__(self, args: list[str], stdin: str | None = None) -> str:
        self.calls.append(args)
        if args[:2] == ["api", f"repos/o/r/compare/main...{self.review_commit}"]:
            return DIFF
        if args[:2] == ["api", "graphql"]:
            assert stdin is not None
            request = json.loads(stdin)
            return json.dumps({"data": self.graphql(request["query"], request["variables"])})
        raise AssertionError(f"unexpected gh call: {args}")

    def graphql(self, query: str, variables: dict[str, Any]) -> dict[str, Any]:
        for name in MUTATIONS:
            if name in query:
                self.mutations.append((name, variables))
                if name == "addPullRequestReviewThread":
                    return {name: {"thread": {"comments": {"nodes": [{"id": "C_new"}]}}}}
                if name == "submitPullRequestReview":
                    return {name: {"pullRequestReview": {"url": "https://github.com/o/r/pull/7#review", "state": "COMMENTED"}}}
                return {name: {"clientMutationId": None}}
        if "viewer { login }" in query:
            return {"viewer": {"login": "me"}, "repository": {"pullRequest": self.pull()}}
        if "reviewThreads" in query:
            return {"repository": {"pullRequest": {"reviewThreads": {"nodes": self.threads()}}}}
        if "files(first" in query:
            files = [
                {"path": "app/models/user.rb", "viewerViewedState": "DISMISSED"},
                {"path": "db/x.sql", "viewerViewedState": "VIEWED"},
            ]
            return {"repository": {"pullRequest": {"files": {"nodes": files}}}}
        if "node(id" in query:
            mine = variables["id"] == "C_1"
            node = {"id": variables["id"], "path": "app/models/user.rb", "line": 11, "body": "hi"}
            return {
                "node": node | {"startLine": self.c1_start_line, "pullRequestReview": {"id": "R_1" if mine else "R_published"}}
            }
        raise AssertionError(f"unexpected query: {query[:60]}")

    def pull(self) -> dict[str, Any]:
        comment = {"id": "C_1", "path": "app/models/user.rb", "line": 11, "startLine": self.c1_start_line, "body": "hi"}
        review = {"id": "R_1", "author": {"login": "me"}, "commit": {"oid": self.review_commit}, "comments": {"nodes": [comment]}}
        return {
            "id": "PR_1",
            "url": "https://github.com/o/r/pull/7",
            "headRefOid": self.head,
            "baseRefName": "main",
            "reviews": {"nodes": [review]},
        }

    def threads(self) -> list[dict[str, Any]]:
        def thread(comment_id: str, author: str, side: str, resolved: bool = False) -> dict[str, Any]:
            first = {"id": comment_id, "author": {"login": author}}
            return {"path": "app/models/user.rb", "isResolved": resolved, "diffSide": side, "comments": {"nodes": [first]}}

        return [thread("C_1", "me", self.c1_side), thread("C_x", "them", "RIGHT"), thread("C_y", "them", "RIGHT", True)]


@pytest.fixture
def state(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path))
    return tmp_path


def run_json(fake: FakeGh, capsys, *argv: str) -> tuple[int, dict[str, Any]]:
    code = gh_review.main(["--pr", "o/r#7", *argv], gh=GitHub(run=fake))
    return code, json.loads(capsys.readouterr().out)


def import_findings(fake: FakeGh, capsys, state: Path, findings: list[dict[str, Any]], head: str = "h1") -> dict[str, Any]:
    path = state / "findings.json"
    path.write_text(json.dumps(findings))
    code, out = run_json(fake, capsys, "findings", "import", str(path), "--head-sha", head)
    assert code == 0, out
    return out


def inbox() -> gh_review.Inbox:
    found = gh_review.load_inbox(PR)
    assert found is not None, "expected a local findings inbox"
    return found


FINDING: dict[str, Any] = {
    "severity": "Important",
    "path": "app/models/user.rb",
    "line": 11,
    "snippet": "@name.strip",
    "title": "strip hides nil",
    "what": "strip raises on nil",
    "why": "name is optional",
}


# ── Outward-facing gates ─────────────────────────────────────────────────────


@pytest.mark.parametrize("command", [["submit", "--event", "APPROVE"], ["discard"]])
def test_outward_actions_refuse_without_yes_before_touching_github(command, capsys):
    fake = FakeGh()
    code = gh_review.main(command, gh=GitHub(run=fake))
    assert code == 1
    assert "without --yes" in json.loads(capsys.readouterr().out)["error"]
    assert fake.calls == []


def test_submit_with_yes_publishes_and_reports_untriaged_findings_left(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING])
    code, out = run_json(fake, capsys, "submit", "--event", "COMMENT", "--body", "Looks close.", "--yes")
    assert code == 0 and out["untriaged_left"] == 1
    assert fake.mutations == [("submitPullRequestReview", {"id": "R_1", "event": "COMMENT", "body": "Looks close."})]


def test_published_comments_are_never_edited_or_deleted(capsys):
    fake = FakeGh()
    for argv in (["edit", "C_other", "--body", "x"], ["rm", "C_other"]):
        code, out = run_json(fake, capsys, *argv)
        assert code == 1 and "isn't in your pending review" in out["error"]
    assert fake.mutations == []


def test_rm_deletes_a_pending_comment(capsys):
    fake = FakeGh()
    code, out = run_json(fake, capsys, "rm", "C_1")
    assert code == 0 and out == {"deleted": "C_1"}
    assert fake.mutations == [("deletePullRequestReviewComment", {"id": "C_1"})]


# ── Anchoring: nothing lands on a guessed line ───────────────────────────────


def test_accepting_a_finding_posts_at_its_position_and_clears_it_from_the_inbox(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING])

    code, out = run_json(fake, capsys, "add", "--finding", "f1", "--body", "Could `name` be nil here?")

    assert code == 0 and out["comment_id"] == "C_new"
    [(_, variables)] = fake.mutations
    assert variables["input"] == {
        "pullRequestReviewId": "R_1",
        "path": "app/models/user.rb",
        "body": "Could `name` be nil here?",
        "subjectType": "LINE",
        "line": 11,
        "side": "RIGHT",
    }
    assert inbox().untriaged == []


def test_positions_are_validated_against_the_review_commit_diff(capsys):
    fake = FakeGh()
    code, _ = run_json(fake, capsys, "add", "--path", "app/models/user.rb", "--line", "11", "--body", "x")
    assert code == 0
    assert ["api", "repos/o/r/compare/main...h1"] in [call[:2] for call in fake.calls]


def test_finding_whose_code_moved_is_refused_and_kept(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING | {"line": 12}])

    code, out = run_json(fake, capsys, "add", "--finding", "f1", "--body", "x")

    assert code == 1 and "no longer matches finding f1" in out["error"]
    assert fake.mutations == []
    assert [f.id for f in inbox().untriaged] == ["f1"]


def test_snippet_must_match_the_whole_line_not_a_fragment(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING | {"snippet": "@name"}])
    code, out = run_json(fake, capsys, "add", "--finding", "f1", "--body", "x")
    assert code == 1 and "no longer matches" in out["error"]
    assert fake.mutations == []


def test_finding_without_a_snippet_needs_an_explicit_line(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING | {"snippet": None}])
    code, out = run_json(fake, capsys, "add", "--finding", "f1", "--body", "x")
    assert code == 1 and "no snippet" in out["error"]
    assert fake.mutations == []


def test_finding_drafted_at_another_commit_is_refused_until_relocated(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING], head="h0")

    code, out = run_json(fake, capsys, "add", "--finding", "f1", "--body", "x")
    assert code == 1 and "drafted at h0" in out["error"]
    assert fake.mutations == []

    code, _ = run_json(fake, capsys, "add", "--finding", "f1", "--line", "11", "--body", "x")
    assert code == 0


def test_explicit_line_relocates_a_finding_without_the_snippet_check(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING | {"line": 12}])

    code, _ = run_json(fake, capsys, "add", "--finding", "f1", "--line", "11", "--body", "x")

    assert code == 0
    assert fake.mutations[0][1]["input"]["line"] == 11


def test_line_comments_are_blocked_once_the_head_moves(state, capsys):
    fake = FakeGh(head="h2", review_commit="h1")
    code, out = run_json(fake, capsys, "add", "--path", "app/models/user.rb", "--line", "11", "--body", "x")
    assert code == 1 and "head moved" in out["error"]
    assert fake.mutations == []


def test_body_edits_still_work_after_the_head_moves(capsys):
    fake = FakeGh(head="h2", review_commit="h1")
    code, _ = run_json(fake, capsys, "edit", "C_1", "--body", "reworded")
    assert code == 0
    assert fake.mutations == [("updatePullRequestReviewComment", {"id": "C_1", "body": "reworded"})]


# ── Moving comments ──────────────────────────────────────────────────────────


def test_move_creates_the_new_comment_before_deleting_the_old(capsys):
    fake = FakeGh()
    code, out = run_json(fake, capsys, "edit", "C_1", "--line", "42")
    assert code == 0 and out["comment_id"] == "C_new"
    assert [name for name, _ in fake.mutations] == ["addPullRequestReviewThread", "deletePullRequestReviewComment"]
    assert fake.mutations[0][1]["input"]["body"] == "hi"


def test_move_keeps_a_comment_on_its_original_side(capsys):
    fake = FakeGh(c1_side="LEFT")
    code, _ = run_json(fake, capsys, "edit", "C_1", "--line", "11")
    assert code == 0
    assert fake.mutations[0][1]["input"]["side"] == "LEFT"


def test_moving_a_range_comment_requires_choosing_the_new_range(capsys):
    fake = FakeGh(c1_start_line=10)
    code, out = run_json(fake, capsys, "edit", "C_1", "--line", "42")
    assert code == 1 and "spans lines 10-11" in out["error"]
    assert fake.mutations == []

    code, _ = run_json(fake, capsys, "edit", "C_1", "--line", "42", "--start-line", "42")
    assert code == 0
    assert "startLine" not in fake.mutations[0][1]["input"]


# ── Inbox and status ─────────────────────────────────────────────────────────


def test_malformed_findings_are_rejected_without_touching_the_inbox(state, capsys):
    fake = FakeGh()
    bad = state / "bad.json"
    bad.write_text(json.dumps([{"severity": "spicy", "path": "x"}]))
    code, out = run_json(fake, capsys, "findings", "import", str(bad), "--head-sha", "h1")
    assert code == 1 and "doesn't match the schema" in out["error"]
    assert gh_review.load_inbox(PR) is None


def test_missing_findings_file_is_a_json_error_not_a_traceback(state, capsys):
    code, out = run_json(FakeGh(), capsys, "findings", "import", str(state / "nope.json"), "--head-sha", "h1")
    assert code == 1 and "nope.json" in out["error"]


def test_single_line_ranges_are_normalized_at_import(state, capsys):
    import_findings(FakeGh(), capsys, state, [FINDING | {"start_line": 11}])
    assert inbox().findings[0].start_line is None


def test_dropped_findings_leave_the_untriaged_list(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING, FINDING | {"title": "second"}])

    code, out = run_json(fake, capsys, "findings", "drop", "f1", "--reason", "intentional")

    assert code == 0 and out["untriaged_left"] == 1
    assert inbox().head_sha == "h1"
    assert inbox().findings[0].drop_reason == "intentional"
    code, out = run_json(fake, capsys, "add", "--finding", "f1", "--body", "x")
    assert code == 1 and "already dropped" in out["error"]


def test_reimport_keeps_the_drop_log_and_never_reuses_ids(state, capsys):
    fake = FakeGh()
    import_findings(fake, capsys, state, [FINDING, FINDING | {"title": "second"}])
    run_json(fake, capsys, "findings", "drop", "f1")

    out = import_findings(fake, capsys, state, [FINDING | {"title": "third"}])

    assert out["imported"] == ["f3"]
    assert [(f.id, f.state) for f in inbox().findings] == [("f1", "dropped"), ("f3", "untriaged")]


def test_status_reports_viewed_state_my_comment_sides_and_others_open_threads(state, capsys):
    fake = FakeGh(c1_side="LEFT")
    import_findings(fake, capsys, state, [FINDING], head="h0")

    code, out = run_json(fake, capsys, "status")

    assert code == 0
    user, sql = out["files"]
    assert user["viewed"] == "changed_since_viewed" and sql["viewed"] == "viewed"
    assert [(c["id"], c["side"]) for c in user["my_comments"]] == [("C_1", "LEFT")]
    assert user["others_open_threads"] == 1
    assert out["inbox"]["stale"] is True and [f["id"] for f in out["inbox"]["untriaged"]] == ["f1"]


def test_pr_references_parse_without_calling_github():
    fake = FakeGh()
    gh = GitHub(run=fake)
    assert gh_review.parse_pr("https://github.com/o/r/pull/7/files", gh) == PR
    assert gh_review.parse_pr("o/r#7", gh) == PR
    assert fake.calls == []
    with pytest.raises(ReviewError, match="Can't read PR reference"):
        gh_review.parse_pr("nope", gh)
