#!/bin/bash
# install.sh [--dim VALUE] [--preset NAME] — sets up the agent status light on macOS.
# Safe to re-run. Does NOT overwrite an existing ~/.cursor/hooks.json.
set -euo pipefail

DIM="1.0"
PRESET="traffic"
while [ $# -gt 0 ]; do
  case "$1" in
    --dim) DIM="$2"; shift 2 ;;
    --dim=*) DIM="${1#*=}"; shift ;;
    --preset) PRESET="$2"; shift 2 ;;
    --preset=*) PRESET="${1#*=}"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BUSYSERVE_LABEL="com.$(whoami).busyserve"
WATCHDOG_LABEL="com.$(whoami).flagwatchdog"

echo "== Agent Status Light installer (dim=$DIM, preset=$PRESET) =="

# --- 0. Preconditions -------------------------------------------------------
if ! ioreg -p IOUSB -w0 | grep -qi 'LUXAFOR'; then
  echo "WARNING: no Luxafor device visible on USB. Plug it in with a DATA cable"
  echo "         (many USB-C cables are charge-only) and re-run. Continuing anyway..."
fi

if ! command -v busyserve >/dev/null 2>&1; then
  echo "busyserve not found. Install it first:"
  echo "  uv tool install 'busylight-for-humans[webapi]'"
  exit 1
fi
BUSYSERVE_PATH="$(command -v busyserve)"
echo "busyserve: $BUSYSERVE_PATH"

if pgrep -fl 'Luxafor' >/dev/null 2>&1; then
  echo "WARNING: the Luxafor desktop app appears to be running. Quit it (menu bar too)."
fi

# --- 1. Scripts --------------------------------------------------------------
mkdir -p "$HOME/.local/bin" "$HOME/.cursor/hooks" "$HOME/.config/agent-status-light"

cp "$REPO_DIR/scripts/light-dim.sh"     "$HOME/.local/bin/light-dim"
cp "$REPO_DIR/scripts/light-color.sh"   "$HOME/.local/bin/light-color"
cp "$REPO_DIR/scripts/light-preset.sh"  "$HOME/.local/bin/light-preset"
cp "$REPO_DIR/scripts/_lib.sh"          "$HOME/.local/bin/_lib.sh"
chmod +x "$HOME/.local/bin/light-dim" "$HOME/.local/bin/light-color" "$HOME/.local/bin/light-preset"

# Copy the Claude Code hooks fragment so the CLIs can find it after the repo
# is deleted. _lib.sh looks here as a fallback.
mkdir -p "$HOME/.local/share/agent-status-light"
cp "$REPO_DIR/claude-code/settings-hooks.json" "$HOME/.local/share/agent-status-light/settings-hooks.json"

sed "s|__BUSYSERVE_LABEL__|$BUSYSERVE_LABEL|" \
  "$REPO_DIR/scripts/flag-watchdog.sh" > "$HOME/.local/bin/flag-watchdog.sh"
chmod +x "$HOME/.local/bin/flag-watchdog.sh"

cp "$REPO_DIR/scripts/light.sh" "$HOME/.cursor/hooks/light.sh"
chmod +x "$HOME/.cursor/hooks/light.sh"

cp "$REPO_DIR/scripts/log-hook.sh" "$HOME/.cursor/hooks/log-hook.sh"
chmod +x "$HOME/.cursor/hooks/log-hook.sh"

# Seed config: apply preset, then dim
bash "$HOME/.local/bin/light-preset" "$PRESET" >/dev/null 2>&1 || true
bash "$HOME/.local/bin/light-dim"    "$DIM"    >/dev/null 2>&1 || true

echo "scripts installed. CLIs: light-dim, light-color, light-preset"

# --- 2. LaunchAgents ---------------------------------------------------------
mkdir -p "$HOME/Library/LaunchAgents"

sed -e "s|__BUSYSERVE_LABEL__|$BUSYSERVE_LABEL|" \
    -e "s|__BUSYSERVE_PATH__|$BUSYSERVE_PATH|" \
    "$REPO_DIR/launchagents/busyserve.plist.template" \
    > "$HOME/Library/LaunchAgents/$BUSYSERVE_LABEL.plist"

sed -e "s|__WATCHDOG_LABEL__|$WATCHDOG_LABEL|" \
    -e "s|__WATCHDOG_PATH__|$HOME/.local/bin/flag-watchdog.sh|" \
    "$REPO_DIR/launchagents/flagwatchdog.plist.template" \
    > "$HOME/Library/LaunchAgents/$WATCHDOG_LABEL.plist"

plutil -lint "$HOME/Library/LaunchAgents/$BUSYSERVE_LABEL.plist" >/dev/null
plutil -lint "$HOME/Library/LaunchAgents/$WATCHDOG_LABEL.plist"  >/dev/null

launchctl unload "$HOME/Library/LaunchAgents/$BUSYSERVE_LABEL.plist" 2>/dev/null || true
launchctl unload "$HOME/Library/LaunchAgents/$WATCHDOG_LABEL.plist"  2>/dev/null || true
launchctl load   "$HOME/Library/LaunchAgents/$BUSYSERVE_LABEL.plist"
launchctl load   "$HOME/Library/LaunchAgents/$WATCHDOG_LABEL.plist"

echo "launch agents loaded."

# --- 3. Cursor hooks ---------------------------------------------------------
if [ -f "$HOME/.cursor/hooks.json" ]; then
  echo "SKIP: ~/.cursor/hooks.json exists. Merge $REPO_DIR/cursor/hooks.json manually."
else
  sed "s|__HOME__|$HOME|g" "$REPO_DIR/cursor/hooks.json" > "$HOME/.cursor/hooks.json"
  echo "~/.cursor/hooks.json installed. RESTART CURSOR to load it."
fi

# --- 4. Claude Code hooks ---------------------------------------------------
if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
  if command -v jq >/dev/null 2>&1; then
    echo "Claude Code detected — running install-claude-hooks.sh..."
    "$REPO_DIR/install-claude-hooks.sh"
  else
    echo "Claude Code detected but jq is missing (brew install jq)."
    echo "Then run: $REPO_DIR/install-claude-hooks.sh"
  fi
else
  echo "Claude Code not detected. To wire it up later: $REPO_DIR/install-claude-hooks.sh"
fi

# --- 5. Verify ---------------------------------------------------------------
sleep 3
if curl -s -m 3 'http://localhost:8631/lights/0/status' | grep -q 'Flag'; then
  echo "busyserve is up and sees the Flag. Flashing green..."
  curl -s 'http://localhost:8631/light/0/on?color=green' >/dev/null
  sleep 2
  curl -s 'http://localhost:8631/light/0/off' >/dev/null
  echo "== Done. =="
else
  echo "busyserve is not answering on localhost:8631."
  echo "Check: tail /tmp/busyserve.log ; launchctl list | grep busyserve"
fi
