#!/bin/bash
# light-color <state> <color>
# state:  thinking | working | needs_input | done
# color:  any CSS3 name (yellow, hotpink, teal...), hex (0xff8800), or 'off'
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

if [ $# -ne 2 ]; then
  echo "Usage: light-color <state> <color>"
  echo "  states: thinking, working, needs_input, done"
  echo "  color:  any CSS3 name, hex (0xff8800), or 'off'"
  echo "Current:"
  print_state
  exit 1
fi

STATE="$1"
COLOR="$2"

# Normalize common typos on the two-word state
case "$STATE" in
  need_input|needs-input|need-input|needinput|needsinput) STATE=needs_input ;;
esac

if ! valid_state "$STATE"; then
  echo "Invalid state: $STATE (must be: thinking, working, needs_input, done)"
  exit 1
fi

load_config
case "$STATE" in
  thinking)    COLOR_THINKING="$COLOR" ;;
  working)     COLOR_WORKING="$COLOR" ;;
  needs_input) COLOR_NEEDS_INPUT="$COLOR" ;;
  done)        COLOR_DONE="$COLOR" ;;
esac
save_config
rewrite_claude_settings
echo "Set $STATE = $COLOR"
