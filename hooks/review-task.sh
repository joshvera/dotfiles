#!/usr/bin/env bash
#
# review-task.sh - Hook to review task implementation with Codex
#
# This hook is triggered on_task_complete to invoke Codex review on the
# task implementation. It compares the commit diff against the task spec
# to validate the implementation matches requirements.
#
# Environment Variables (provided by wiggum):
#   WIGGUM_TASK_ID    - Task number from the plan (e.g., "8")
#   WIGGUM_TASK_TITLE - Task description (e.g., "Add authentication")
#   WIGGUM_COMMIT_SHA - Git commit hash for the task
#   WIGGUM_PLAN_FILE  - Path to the implementation plan file
#
# Exit Codes:
#   0 - Review passed (or Claude CLI not available)
#   1 - Review rejected the implementation
#

set -euo pipefail

# Validate required environment variables
if [[ -z "${WIGGUM_TASK_ID:-}" ]]; then
  echo "ERROR: WIGGUM_TASK_ID environment variable not set" >&2
  exit 1
fi

if [[ -z "${WIGGUM_COMMIT_SHA:-}" ]]; then
  echo "ERROR: WIGGUM_COMMIT_SHA environment variable not set" >&2
  exit 1
fi

# Check if claude CLI is available
if ! command -v claude >/dev/null 2>&1; then
  echo "WARNING: claude CLI not found in PATH - skipping task review" >&2
  exit 0
fi

# Get the commit diff
DIFF=$(git show "$WIGGUM_COMMIT_SHA" --stat --patch 2>/dev/null || echo "")
if [[ -z "$DIFF" ]]; then
  echo "WARNING: Could not get diff for commit $WIGGUM_COMMIT_SHA" >&2
  exit 0
fi

# Extract task spec from plan file if available
TASK_SPEC=""
if [[ -n "${WIGGUM_PLAN_FILE:-}" ]] && [[ -f "$WIGGUM_PLAN_FILE" ]]; then
  # Extract the task section from the plan (### N. Title through next ### or ## section)
  TASK_SPEC=$(awk -v task_id="$WIGGUM_TASK_ID" '
    $0 ~ "^### " task_id "\\." { found=1 }
    found && /^###? / && !($0 ~ "^### " task_id "\\.") { exit }
    found { print }
  ' "$WIGGUM_PLAN_FILE")
fi

# Build review prompt
TASK_TITLE="${WIGGUM_TASK_TITLE:-Task $WIGGUM_TASK_ID}"

echo "Invoking Codex review on task implementation..." >&2

# Pass review request to claude CLI, capture output
REVIEW_OUTPUT=$(mktemp)
trap "rm -f '$REVIEW_OUTPUT'" EXIT

claude "/codex-review medium - Review this task implementation:

## Task
$TASK_TITLE

## Task Spec
${TASK_SPEC:-No spec available}

## Implementation Diff
\`\`\`diff
$DIFF
\`\`\`

Check that:
1. Implementation matches the task spec/acceptance criteria
2. No obvious bugs or issues introduced
3. Code follows project conventions

If the implementation is acceptable, exit 0. If there are issues that need fixing, exit 1." 2>&1 | tee "$REVIEW_OUTPUT"

REVIEW_EXIT_CODE=${PIPESTATUS[0]}

# If review rejected, append feedback to the plan so next iteration sees it
if [ $REVIEW_EXIT_CODE -ne 0 ] && [ -n "${WIGGUM_PLAN_FILE:-}" ] && [ -f "$WIGGUM_PLAN_FILE" ]; then
  echo "" >> "$WIGGUM_PLAN_FILE"
  echo "### Review Feedback (Task $WIGGUM_TASK_ID)" >> "$WIGGUM_PLAN_FILE"
  echo "" >> "$WIGGUM_PLAN_FILE"
  echo "**Status**: Rejected by codex-review" >> "$WIGGUM_PLAN_FILE"
  echo "" >> "$WIGGUM_PLAN_FILE"
  cat "$REVIEW_OUTPUT" >> "$WIGGUM_PLAN_FILE"
  echo "" >> "$WIGGUM_PLAN_FILE"

  # Commit the feedback so next iteration sees it
  git add "$WIGGUM_PLAN_FILE" 2>/dev/null || true
  git commit -m "docs: add codex-review feedback for task $WIGGUM_TASK_ID" 2>/dev/null || true

  echo "Review feedback appended to $WIGGUM_PLAN_FILE" >&2
fi

exit $REVIEW_EXIT_CODE
