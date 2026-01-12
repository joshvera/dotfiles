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
#   0 - Success (or Claude CLI not available, or review failed - non-blocking)
#   1 - Plan file missing (WIGGUM_PLAN_FILE not set or file doesn't exist)
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

# Pass review request to claude CLI
# The command structure asks Codex to review the plan at medium reasoning effort
if ! claude "/codex-review medium - Review this implementation plan:

$plan_content"; then
  echo "WARNING: Codex review failed (exit code $?) - continuing anyway" >&2
  # Don't block on review failure - reviews are informational
  exit 0
fi

exit 0
