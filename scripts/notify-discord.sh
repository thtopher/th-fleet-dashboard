#!/bin/bash
# ~/th-fleet-dashboard/scripts/notify-discord.sh
# Sends notifications to Discord ops channel
# Usage: notify-discord.sh <kind> <gateway-key> [prev-status] [new-status]
set -euo pipefail

# Load webhook URL from env file (not in repo)
if [ -f ~/.th-fleet-dashboard-env ]; then
  source ~/.th-fleet-dashboard-env
fi

# If no webhook configured, exit silently
if [ -z "${DISCORD_OPS_WEBHOOK:-}" ]; then
  exit 0
fi

KIND="${1:-}"
KEY="${2:-}"
PREV="${3:-}"
CURR="${4:-}"

case "$KIND-$CURR" in
  state-flip-up)
    ICON="✅"
    TEXT="$KEY recovered (was $PREV)"
    ;;
  state-flip-down)
    ICON="❌"
    TEXT="$KEY went down (was $PREV)"
    ;;
  state-flip-degraded)
    ICON="⚠️"
    TEXT="$KEY degraded (was $PREV)"
    ;;
  state-flip-*)
    ICON="ℹ️"
    TEXT="$KEY status changed: $PREV → $CURR"
    ;;
  action-success)
    ICON="✅"
    TEXT="$KEY restart succeeded"
    ;;
  action-failure)
    ICON="❌"
    TEXT="$KEY restart failed"
    ;;
  *)
    ICON="ℹ️"
    TEXT="Fleet event: $KIND $KEY"
    ;;
esac

# Send to Discord
curl -s -X POST "$DISCORD_OPS_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg c "$ICON $TEXT" '{content:$c}')" >/dev/null
