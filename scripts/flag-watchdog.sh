#!/bin/bash
# flag-watchdog.sh
# Run every 30s by launchd. When the Luxafor Flag re-enumerates (new IOKit
# registry ID — happens on every dock/undock cycle), busyserve is left holding
# a stale device handle: its API returns success but the light doesn't change.
# Detect the identity change and kickstart busyserve.
#
# Identity (not presence) tracking is deliberate: presence-edge detection
# misses fast replugs and sleeps through lid-closed absences, since launchd
# StartInterval timers don't tick during sleep.

BUSYSERVE_LABEL="__BUSYSERVE_LABEL__"   # filled in by install.sh
STATE=/tmp/flag-device.id

NOW_ID=$(ioreg -p IOUSB -w0 | grep 'LUXAFOR' | sed 's/.*id \(0x[0-9a-f]*\).*/\1/' | head -1)
PREV_ID=$(cat "$STATE" 2>/dev/null)
echo "$NOW_ID" > "$STATE"

# Flag absent (undocked): nothing to fix
[ -z "$NOW_ID" ] && exit 0

# Present with a new identity (or first sighting) -> server handle is stale
if [ "$NOW_ID" != "$PREV_ID" ]; then
  echo "$(date '+%F %T') Flag enumerated as $NOW_ID (was ${PREV_ID:-absent}), kickstarting busyserve" >> /tmp/flag-watchdog.log
  launchctl kickstart -k "gui/$(id -u)/$BUSYSERVE_LABEL"
fi

exit 0
