#!/bin/bash
# light.sh <color|off>
# Called by Cursor hooks. Sets the Luxafor light via busyserve and manages
# silence-watchdog timers:
#   yellow: 60s of no further events -> solid magenta ("probably waiting on you"),
#           180s more -> off
#   green:  20s -> off (idle)
# Any new event kills the pending timer chain.

cat > /dev/null   # discard hook JSON from stdin; we only care that the event fired

COLOR="$1"
BASE="http://localhost:8631/light/0"

if [ "$COLOR" = "off" ]; then
  curl -s -m 2 "$BASE/off" >/dev/null 2>&1
else
  curl -s -m 2 "$BASE/on?color=$COLOR" >/dev/null 2>&1
fi

PIDFILE=/tmp/cursor-light-watchdog.pid
[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null

if [ "$COLOR" = "yellow" ]; then
  ( sleep 60;  curl -s -m 2 "$BASE/on?color=magenta" >/dev/null 2>&1; \
    sleep 180; curl -s -m 2 "$BASE/off" >/dev/null 2>&1 ) &
  echo $! > "$PIDFILE"
elif [ "$COLOR" = "green" ]; then
  ( sleep 20; curl -s -m 2 "$BASE/off" >/dev/null 2>&1 ) &
  echo $! > "$PIDFILE"
fi

exit 0
