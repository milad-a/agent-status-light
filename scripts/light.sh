#!/bin/bash
# light.sh <state|off>
# Called by Cursor hooks. States: thinking, working, needs_input, done, off.
# Each state maps to a color from ~/.config/agent-status-light/config; a state
# whose color is "off" is silently skipped (used by 'subtle' / 'done-only' presets).
# Silence watchdog:
#   thinking: 60s -> needs_input color, 180s more -> off
#   done:     20s -> off
# Any new event kills the pending timer chain.

cat > /dev/null

CONFIG="$HOME/.config/agent-status-light/config"
DIM=1.0
COLOR_THINKING=yellow
COLOR_WORKING=red
COLOR_NEEDS_INPUT=magenta
COLOR_DONE=green
[ -f "$CONFIG" ] && . "$CONFIG"

STATE="$1"
BASE="http://localhost:8631/light/0"

case "$STATE" in
  thinking)    COLOR="$COLOR_THINKING" ;;
  working)     COLOR="$COLOR_WORKING" ;;
  needs_input) COLOR="$COLOR_NEEDS_INPUT" ;;
  done)        COLOR="$COLOR_DONE" ;;
  off)         COLOR="off" ;;
  *)           exit 1 ;;
esac

if [ "$COLOR" = "off" ]; then
  curl -s -m 2 "$BASE/off" >/dev/null 2>&1
else
  curl -s -m 2 "$BASE/on?color=$COLOR&dim=$DIM" >/dev/null 2>&1
fi

PIDFILE=/tmp/cursor-light-watchdog.pid
[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null

if [ "$STATE" = "thinking" ] || [ "$STATE" = "working" ]; then
  ATTN="$COLOR_NEEDS_INPUT"
  ( sleep 60
    if [ "$ATTN" = "off" ]; then
      curl -s -m 2 "$BASE/off" >/dev/null 2>&1
    else
      curl -s -m 2 "$BASE/on?color=$ATTN&dim=$DIM" >/dev/null 2>&1
    fi
    sleep 180
    curl -s -m 2 "$BASE/off" >/dev/null 2>&1 ) &
  echo $! > "$PIDFILE"
elif [ "$STATE" = "done" ]; then
  ( sleep 20; curl -s -m 2 "$BASE/off" >/dev/null 2>&1 ) &
  echo $! > "$PIDFILE"
fi

exit 0
