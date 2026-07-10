#!/bin/bash
# light-dim <value>   e.g. 0.3 = 30% brightness
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_lib.sh"

if [ $# -ne 1 ]; then
  echo "Usage: light-dim <value>   (0.0 to 1.0)"
  echo "Current:"
  print_state
  exit 1
fi

load_config
if ! valid_dim "$1"; then
  echo "Invalid value: $1 (must be between 0.0 and 1.0)"
  exit 1
fi
DIM="$1"
save_config
rewrite_claude_settings
echo "Brightness set to $DIM"
