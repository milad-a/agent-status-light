#!/bin/bash
# light-preset <name>
# Presets:
#   traffic    (default)  thinking=yellow working=red    needs_input=magenta done=green
#   minimal              thinking=yellow working=yellow needs_input=magenta done=green
#   subtle               thinking=off    working=yellow needs_input=magenta done=green
#   done-only            thinking=off    working=off    needs_input=magenta done=green
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

if [ $# -ne 1 ]; then
  echo "Usage: light-preset <traffic|minimal|subtle|done-only>"
  echo "Current:"
  print_state
  exit 1
fi

load_config
case "$1" in
  traffic)
    COLOR_THINKING=yellow; COLOR_WORKING=red; COLOR_NEEDS_INPUT=magenta; COLOR_DONE=green ;;
  minimal)
    COLOR_THINKING=yellow; COLOR_WORKING=yellow; COLOR_NEEDS_INPUT=magenta; COLOR_DONE=green ;;
  subtle)
    COLOR_THINKING=off; COLOR_WORKING=yellow; COLOR_NEEDS_INPUT=magenta; COLOR_DONE=green ;;
  done-only|done_only|doneonly)
    COLOR_THINKING=off; COLOR_WORKING=off; COLOR_NEEDS_INPUT=magenta; COLOR_DONE=green ;;
  *)
    echo "Unknown preset: $1"
    echo "Available: traffic, minimal, subtle, done-only"
    exit 1 ;;
esac
save_config
rewrite_claude_settings
echo "Applied preset: $1"
print_state
