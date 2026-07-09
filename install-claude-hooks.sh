#!/bin/bash
# install-claude-hooks.sh — merges the status-light hooks into ~/.claude/settings.json.
# Safe to re-run: creates a timestamped backup, and overwrites only the specific
# hook events this repo defines. Existing hooks for OTHER events are preserved.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAGMENT="$REPO_DIR/claude-code/settings-hooks.json"
TARGET="$HOME/.claude/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "This script needs jq. Install it with: brew install jq"
  exit 1
fi

if [ ! -f "$FRAGMENT" ]; then
  echo "Fragment not found at $FRAGMENT"
  exit 1
fi

mkdir -p "$HOME/.claude"

# If no settings.json yet, start from an empty object.
if [ ! -f "$TARGET" ]; then
  echo "{}" > "$TARGET"
  echo "Created empty $TARGET."
else
  BACKUP="$TARGET.bak-$(date +%Y%m%d%H%M%S)"
  cp "$TARGET" "$BACKUP"
  echo "Backed up existing settings to $BACKUP"
fi

# Strip the // comment keys from the fragment, then deep-merge:
# * existing top-level keys are preserved
# * the "hooks" object is merged one level deep: events we define are replaced,
#   events we don't touch (e.g. the user's own PostToolUse) are kept
TMP="$(mktemp)"
jq -s '
  .[0] as $current |
  .[1] as $incoming |
  ($incoming | with_entries(select(.key | startswith("//") | not))) as $clean |
  $current * {hooks: (($current.hooks // {}) * ($clean.hooks // {}))}
' "$TARGET" "$FRAGMENT" > "$TMP"

# Validate the result before replacing.
python3 -c "import json; json.load(open('$TMP'))"
mv "$TMP" "$TARGET"

echo "Merged hooks into $TARGET"
echo "Events written: $(jq -r '.hooks | keys | join(", ")' "$TARGET")"
echo
echo "Note: any hooks you previously had for UserPromptSubmit, PreToolUse,"
echo "PostToolUse, Notification, Stop, or SessionEnd have been REPLACED by"
echo "the status-light versions. The backup above has your originals."
