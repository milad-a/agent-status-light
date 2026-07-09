#!/bin/bash
# log-hook.sh (optional, for debugging)
# Add alongside light.sh in hooks.json to capture the raw JSON each hook
# event receives. Useful for discovering what actually fires and when —
# this is how we learned Cursor emits NO event when it asks a plan-mode
# question, and that Claude Code's Notification payload carries
# notification_type: permission_prompt | idle_prompt.

IN=$(cat)
echo "$(date '+%H:%M:%S') $IN" >> /tmp/agent-hooks.log
exit 0
