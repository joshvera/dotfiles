#!/usr/bin/env bash
#
# review-plan.sh - Hook to review implementation plan with Codex
#
# This hook is triggered on_plan_complete to invoke Codex review on the
# generated IMPLEMENTATION_PLAN.md file. It uses the claude CLI to request
# a review at medium reasoning effort.
#
# Environment Variables (provided by wiggum):
#   WIGGUM_PLAN_FILE - Path to the implementation plan file
#
# Exit Codes:
#   0 - Review passed (or Claude CLI not available)
#   1 - Review rejected the plan, or plan file missing
#

set -euo pipefail

# Validate required environment variable
if [[ -z "${WIGGUM_PLAN_FILE:-}" ]]; then
  echo "ERROR: WIGGUM_PLAN_FILE environment variable not set" >&2
  exit 1
fi

# Check if plan file exists
if [[ ! -f "$WIGGUM_PLAN_FILE" ]]; then
  echo "ERROR: Plan file not found: $WIGGUM_PLAN_FILE" >&2
  exit 1
fi

# Check if claude CLI is available
if ! command -v claude >/dev/null 2>&1; then
  echo "WARNING: claude CLI not found in PATH - skipping plan review" >&2
  echo "Install claude CLI to enable automatic plan review with Codex" >&2
  exit 0
fi

# Read plan content
plan_content=$(cat "$WIGGUM_PLAN_FILE")

# Invoke Codex review via claude CLI
echo "Invoking Codex review on implementation plan..." >&2

# Pass review request to claude CLI, capture output
REVIEW_OUTPUT=$(mktemp)
trap "rm -f '$REVIEW_OUTPUT'" EXIT

claude "/codex-review medium - Review this implementation plan:

$plan_content

If the plan is acceptable, exit 0. If there are issues that need fixing, exit 1." 2>&1 | tee "$REVIEW_OUTPUT"

REVIEW_EXIT_CODE=${PIPESTATUS[0]}

# If review rejected, append feedback to the plan so next iteration sees it
if [ $REVIEW_EXIT_CODE -ne 0 ]; then
  echo "" >> "$WIGGUM_PLAN_FILE"
  echo "## Review Feedback" >> "$WIGGUM_PLAN_FILE"
  echo "" >> "$WIGGUM_PLAN_FILE"
  echo "**Status**: Plan rejected by codex-review" >> "$WIGGUM_PLAN_FILE"
  echo "" >> "$WIGGUM_PLAN_FILE"
  cat "$REVIEW_OUTPUT" >> "$WIGGUM_PLAN_FILE"
  echo "" >> "$WIGGUM_PLAN_FILE"

  # Commit the feedback so next iteration sees it
  git add "$WIGGUM_PLAN_FILE" 2>/dev/null || true
  git commit -m "docs: add codex-review feedback for plan" 2>/dev/null || true

  echo "Review feedback appended to $WIGGUM_PLAN_FILE" >&2
fi

exit $REVIEW_EXIT_CODE
