#!/bin/bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[91m'
  C_GREEN=$'\033[92m'
  C_YELLOW=$'\033[93m'
  C_CYAN=$'\033[96m'
  C_GRAY=$'\033[90m'
else
  C_RESET=""
  C_BOLD=""
  C_DIM=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_CYAN=""
  C_GRAY=""
fi

TOTAL=$1
SCRIPT_START=$(date +%s)
HEADER_ROWS=4

TUI_ENABLED=1
if [[ ! -t 1 || -n "${NO_COLOR:-}" || "${RALPH_NO_TUI:-}" = "1" ]]; then
  TUI_ENABLED=0
fi

STATE_FILE=$(mktemp -t ralph-state.XXXXXX)
echo '{}' > "$STATE_FILE"

export RALPH_TOTAL=$TOTAL
export RALPH_SESSION_START=$SCRIPT_START
export RALPH_STATE_FILE=$STATE_FILE
export RALPH_HEADER_ROWS=$HEADER_ROWS

format_elapsed() {
  local seconds=$1
  if (( seconds < 60 )); then
    printf "%ds" "$seconds"
  elif (( seconds < 3600 )); then
    printf "%dm %02ds" $((seconds / 60)) $((seconds % 60))
  else
    printf "%dh %02dm %02ds" $((seconds / 3600)) $(((seconds % 3600) / 60)) $((seconds % 60))
  fi
}

now_clock() {
  date "+%a %H:%M:%S"
}

setup_tui() {
  (( TUI_ENABLED )) || return 0
  local lines
  lines=$(tput lines 2>/dev/null || echo 24)
  printf '\033[2J\033[H'
  printf '\033[%d;%dr' "$((HEADER_ROWS + 1))" "$lines"
  printf '\033[%d;1H' "$((HEADER_ROWS + 1))"
}

teardown_tui() {
  (( TUI_ENABLED )) || return 0
  printf '\033[r'
  local lines
  lines=$(tput lines 2>/dev/null || echo 24)
  printf '\033[%d;1H' "$lines"
}

print_session_header() {
  printf "\n%s┏━━ ralk-afk ━ %s ━ %d iteration(s) requested ━━┓%s\n\n" \
    "$C_BOLD$C_CYAN" "$(date "+%a %Y-%m-%d %H:%M:%S")" "$TOTAL" "$C_RESET"
}

print_iteration_start() {
  local i=$1
  printf "\n%s╭─ Iteration %d/%d ─ started %s%s\n" \
    "$C_BOLD$C_CYAN" "$i" "$TOTAL" "$(now_clock)" "$C_RESET"
}

print_iteration_end() {
  local i=$1
  local elapsed=$2
  local color=$3
  local symbol=$4
  local note=${5:-}
  local suffix=""
  [[ -n "$note" ]] && suffix=" ${C_DIM}— ${note}${C_RESET}${C_BOLD}${color}"
  printf "%s╰─ %s Iteration %d/%d done in %s ─ %s%s%s\n" \
    "$C_BOLD$color" "$symbol" "$i" "$TOTAL" "$(format_elapsed "$elapsed")" \
    "$(now_clock)" "$suffix" "$C_RESET"
}

print_final_banner() {
  local label=$1
  local color=$2
  local elapsed=$(( $(date +%s) - SCRIPT_START ))
  printf "\n%s┗━━ %s ─ total %s ─ %s ━━┛%s\n\n" \
    "$C_BOLD$color" "$label" "$(format_elapsed "$elapsed")" "$(now_clock)" "$C_RESET"
}

cleanup() {
  teardown_tui
  rm -f "$STATE_FILE"
}

on_signal() {
  local sig=$1
  print_final_banner "Stopped by $sig" "$C_RED"
  exit 130
}

trap cleanup EXIT
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM
# Recompute scroll region on terminal resize so the header rows stay reserved.
trap 'lines=$(tput lines 2>/dev/null || echo 24); printf "\033[%d;%dr" "$((HEADER_ROWS + 1))" "$lines"' WINCH

setup_tui
print_session_header

for ((i=1; i<=TOTAL; i++)); do
  print_iteration_start "$i"
  iter_start=$(date +%s)

  tmp=$(mktemp)
  export RALPH_ITER=$i

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

  iter_elapsed=$(( $(date +%s) - iter_start ))

  if (( pretty_status != 0 )); then
    print_iteration_end "$i" "$iter_elapsed" "$C_RED" "✗" "pretty printer failed"
    print_final_banner "Pretty printer failed" "$C_RED"
    exit "$pretty_status"
  fi

  if (( status != 0 )); then
    print_iteration_end "$i" "$iter_elapsed" "$C_RED" "✗" "claude exited with $status"
    print_final_banner "Claude exited with $status" "$C_RED"
    exit "$status"
  fi

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]] && [[ "$result" != *"git commit"* ]] && [[ "$result" != *"gh issue close"* ]]; then
    print_iteration_end "$i" "$iter_elapsed" "$C_GREEN" "✓" "PRD complete"
    print_final_banner "PRD complete after $i iterations" "$C_GREEN"
    exit 0
  elif [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    print_iteration_end "$i" "$iter_elapsed" "$C_YELLOW" "↻" "completion ignored — issue list changed"
  else
    print_iteration_end "$i" "$iter_elapsed" "$C_GREEN" "✓"
  fi
done

print_final_banner "Reached $TOTAL iterations without completion" "$C_YELLOW"
exit 1
