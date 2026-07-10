#!/bin/bash
# install-claude-hooks.sh — merges the status-light hooks into ~/.claude/settings.json
# using the current config values (~/.config/agent-status-light/config).
# Safe to re-run: creates a timestamped backup. Existing hooks for OTHER events are preserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/scripts/_lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "This script needs jq. Install with: brew install jq"
  exit 1
fi

mkdir -p "$HOME/.claude"
if [ ! -f "$CLAUDE_SETTINGS" ]; then
  echo "{}" > "$CLAUDE_SETTINGS"
  echo "Created empty $CLAUDE_SETTINGS."
fi

load_config
rewrite_claude_settings
echo
echo "Events written: $(jq -r '.hooks | keys | join(", ")' "$CLAUDE_SETTINGS")"
echo "Note: any hooks you previously had for UserPromptSubmit, PreToolUse,"
echo "PostToolUse, Notification, Stop, or SessionEnd have been REPLACED by"
echo "the status-light versions. The backup above has your originals."
echo
echo "Change later with: light-dim | light-color | light-preset"
