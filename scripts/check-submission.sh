#!/usr/bin/env bash
# Autograder helper: passes when every "ANSWER:" line in SUBMISSION.md
# has been filled in with at least a few characters.
set -euo pipefail

file="${1:-SUBMISSION.md}"
empty=$(grep -nE 'ANSWER:[[:space:]]*$' "$file" || true)

if [[ -n "$empty" ]]; then
  echo "These answers are still empty in $file:"
  echo "$empty"
  exit 1
fi
echo "All answers filled in."
