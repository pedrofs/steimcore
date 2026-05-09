#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

for ((i=1; i<=$1; i++)); do
  echo "Iteration $i/$1"

  tmp=$(mktemp)

  set +e
  claude \
    --dangerously-skip-permissions \
    --output-format stream-json \
    --include-partial-messages \
    --verbose \
    -p "@ralph-prompt.md" 2>&1 | tee "$tmp" | ruby script/claude_stream_pretty.rb
  statuses=("${PIPESTATUS[@]}")
  status=${statuses[0]}
  pretty_status=${statuses[2]}
  set -e

  result=$(<"$tmp")
  rm "$tmp"

  if (( pretty_status != 0 )); then
    echo "Pretty printer failed."
    exit "$pretty_status"
  fi

  if (( status != 0 )); then
    exit "$status"
  fi

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]] && [[ "$result" != *"git commit"* ]] && [[ "$result" != *"gh issue close"* ]]; then
    echo "PRD complete after $i iterations."
    exit 0
  elif [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "Ignoring completion signal because this iteration changed or closed an issue; refreshing issue list."
  fi
done

echo "Reached $1 iterations without completion."
exit 1
