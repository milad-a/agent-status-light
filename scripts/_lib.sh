#!/bin/bash
# Shared functions for light-dim / light-color / light-preset.
# Sourced by CLI scripts. Works both from the repo (during development) and
# after install (from ~/.local/bin) — install.sh copies the fragment next to
# _lib.sh so it can be found regardless.

CONFIG_DIR="$HOME/.config/agent-status-light"
CONFIG_FILE="$CONFIG_DIR/config"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

DIM_DEFAULT=1.0
COLOR_THINKING_DEFAULT=yellow
COLOR_WORKING_DEFAULT=red
COLOR_NEEDS_INPUT_DEFAULT=magenta
COLOR_DONE_DEFAULT=green

# Locate the Claude Code hooks fragment. Repo layout:
#   scripts/_lib.sh  <->  claude-code/settings-hooks.json
# Installed layout:
#   ~/.local/bin/_lib.sh  <->  ~/.local/share/agent-status-light/settings-hooks.json
_locate_fragment() {
  local LIB_DIR
  LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if   [ -f "$LIB_DIR/../claude-code/settings-hooks.json" ]; then
    echo "$LIB_DIR/../claude-code/settings-hooks.json"
  elif [ -f "$HOME/.local/share/agent-status-light/settings-hooks.json" ]; then
    echo "$HOME/.local/share/agent-status-light/settings-hooks.json"
  else
    return 1
  fi
}

load_config() {
  DIM=$DIM_DEFAULT
  COLOR_THINKING=$COLOR_THINKING_DEFAULT
  COLOR_WORKING=$COLOR_WORKING_DEFAULT
  COLOR_NEEDS_INPUT=$COLOR_NEEDS_INPUT_DEFAULT
  COLOR_DONE=$COLOR_DONE_DEFAULT
  if [ -f "$CONFIG_FILE" ]; then . "$CONFIG_FILE"; fi
  return 0
}

save_config() {
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_FILE" << EOC
DIM=$DIM
COLOR_THINKING=$COLOR_THINKING
COLOR_WORKING=$COLOR_WORKING
COLOR_NEEDS_INPUT=$COLOR_NEEDS_INPUT
COLOR_DONE=$COLOR_DONE
EOC
}

valid_dim()   { echo "$1" | grep -Eq '^(0(\.[0-9]+)?|1(\.0+)?)$'; }
valid_state() {
  case "$1" in thinking|working|needs_input|done) return 0 ;; *) return 1 ;; esac
}

# Regenerate ~/.claude/settings.json hooks from the fragment using current config.
rewrite_claude_settings() {
  [ -f "$CLAUDE_SETTINGS" ] || return 0
  command -v jq >/dev/null 2>&1 || {
    echo "Skipping ~/.claude/settings.json update: jq not installed"
    return 0
  }

  local FRAGMENT
  FRAGMENT="$(_locate_fragment)" || {
    echo "Skipping Claude Code update: fragment not found"
    return 0
  }

  local BACKUP="$CLAUDE_SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
  cp "$CLAUDE_SETTINGS" "$BACKUP"

  local FRAGMENT_TMP
  FRAGMENT_TMP="$(mktemp)"
  sed -e "s|__THINKING__|$COLOR_THINKING|g" \
      -e "s|__WORKING__|$COLOR_WORKING|g" \
      -e "s|__NEEDS_INPUT__|$COLOR_NEEDS_INPUT|g" \
      -e "s|__DONE__|$COLOR_DONE|g" \
      -e "s|__DIM__|$DIM|g" \
      "$FRAGMENT" > "$FRAGMENT_TMP"

  # Neutralize color=off URLs to a no-op ':'
  python3 - "$FRAGMENT_TMP" << 'PY'
import json, sys
p = sys.argv[1]
with open(p) as f: data = json.load(f)
def walk(node):
    if isinstance(node, dict):
        cmd = node.get("command")
        if isinstance(cmd, str) and "color=off" in cmd:
            node["command"] = ":"
        for v in node.values(): walk(v)
    elif isinstance(node, list):
        for v in node: walk(v)
walk(data)
with open(p, 'w') as f: json.dump(data, f, indent=2)
PY

  local TMP
  TMP="$(mktemp)"
  jq -s '
    .[0] as $current |
    .[1] as $incoming |
    ($incoming | with_entries(select(.key | startswith("//") | not))) as $clean |
    $current * {hooks: (($current.hooks // {}) * ($clean.hooks // {}))}
  ' "$CLAUDE_SETTINGS" "$FRAGMENT_TMP" > "$TMP"

  python3 -c "import json; json.load(open('$TMP'))"
  mv "$TMP" "$CLAUDE_SETTINGS"
  rm "$FRAGMENT_TMP"
  echo "Updated $CLAUDE_SETTINGS (backup: $BACKUP)"
}

print_state() {
  load_config
  echo "  dim         = $DIM"
  echo "  thinking    = $COLOR_THINKING"
  echo "  working     = $COLOR_WORKING"
  echo "  needs_input = $COLOR_NEEDS_INPUT"
  echo "  done        = $COLOR_DONE"
}
