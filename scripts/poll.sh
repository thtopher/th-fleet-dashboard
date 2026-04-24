#!/bin/bash
# ~/th-fleet-dashboard/scripts/poll.sh
# Runs from cron on the Hostinger VPS.
# Probes OpenClaw gateways and updates status.json + history.jsonl
set -euo pipefail

export TZ="America/Chicago"
export PATH="/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin"

REPO_DIR="$HOME/th-fleet-dashboard"
cd "$REPO_DIR"

# 1. Determine poll interval based on Central time
# Business hours: 7 AM - 11 PM CT = 60s
# Overnight: 11 PM - 7 AM CT = 300s
HOUR=$(date +%-H)
if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 23 ]; then
  POLL_INTERVAL=60
  # During business hours, run every minute
else
  POLL_INTERVAL=300
  # Overnight: only run if minute is divisible by 5
  MINUTE=$(date +%-M)
  if [ $((MINUTE % 5)) -ne 0 ]; then
    exit 0
  fi
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 2. Probe an OpenClaw gateway
# Usage: probe_gateway <key> <ssh_host> <proc_pattern> <log_path>
# ssh_host is empty string for local probes
probe_gateway() {
  local key="$1"
  local ssh_host="$2"
  local proc_pattern="$3"
  local log_path="$4"

  local ssh_cmd=""
  if [ -n "$ssh_host" ]; then
    ssh_cmd="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 $ssh_host"
  fi

  # Get PID
  local pid
  pid=$($ssh_cmd pgrep -f "$proc_pattern" 2>/dev/null | head -n1 || true)

  if [ -z "$pid" ]; then
    jq -n --arg t "$TIMESTAMP" \
      '{status:"down", pid:null, discord_connected:false, last_message_at:null, last_checked_at:$t, last_red_event_at:$t, details:"Process not found"}'
    return
  fi

  # Get last ~200 lines of log (handle binary nulls)
  local log_tail
  log_tail=$($ssh_cmd "cat '$log_path' 2>/dev/null | tr -d '\\0' | tail -n 200" 2>/dev/null || echo "")

  # Parse connection state from log
  # "logged in to discord" or "client initialized" = connected
  # "Gateway websocket closed" followed by "reconnect scheduled" = brief disconnect, usually recovers
  # "stale-socket" = health monitor restart (common, not necessarily bad)
  
  local discord_connected=true
  local last_event=""
  
  # Check for recent disconnect without reconnect
  if echo "$log_tail" | tail -5 | grep -qE "Gateway websocket closed|disconnected" && \
     ! echo "$log_tail" | tail -5 | grep -qE "logged in|initialized|reconnect"; then
    discord_connected=false
  fi

  # Get the timestamp of the most recent log line
  local last_msg
  last_msg=$(echo "$log_tail" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | tail -n1 || true)

  # Determine status
  local status="up"
  if [ "$discord_connected" = false ]; then
    status="degraded"
  fi

  # Build JSON output
  jq -n \
    --arg s "$status" \
    --arg t "$TIMESTAMP" \
    --arg lm "${last_msg:-}" \
    --argjson pid "$pid" \
    --argjson dc "$discord_connected" \
    '{
      status: $s,
      pid: $pid,
      discord_connected: $dc,
      last_message_at: (if $lm == "" then null else ($lm + "Z") end),
      last_checked_at: $t,
      last_red_event_at: null,
      details: null
    }'
}

# Probe a systemd-managed gateway (PID provided directly)
probe_gateway_systemd() {
  local key="$1"
  local ssh_host="$2"
  local pid="$3"
  local log_path="$4"

  local ssh_cmd=""
  if [ -n "$ssh_host" ]; then
    ssh_cmd="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 $ssh_host"
  fi

  # Verify PID is still alive
  if ! $ssh_cmd "kill -0 $pid" 2>/dev/null; then
    jq -n --arg t "$TIMESTAMP" \
      '{status:"down", pid:null, discord_connected:false, last_message_at:null, last_checked_at:$t, last_red_event_at:$t, details:"PID not running"}'
    return
  fi

  # Get last ~200 lines of log (handle binary nulls)
  local log_tail
  log_tail=$($ssh_cmd "cat '$log_path' 2>/dev/null | tr -d '\\0' | tail -n 200" 2>/dev/null || echo "")

  local discord_connected=true
  
  # Check for recent disconnect without reconnect
  if echo "$log_tail" | tail -5 | grep -qE "Gateway websocket closed|disconnected" && \
     ! echo "$log_tail" | tail -5 | grep -qE "logged in|initialized|reconnect"; then
    discord_connected=false
  fi

  # Get the timestamp of the most recent log line
  local last_msg
  last_msg=$(echo "$log_tail" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | tail -n1 || true)

  # Determine status
  local status="up"
  if [ "$discord_connected" = false ]; then
    status="degraded"
  fi

  # Build JSON output
  jq -n \
    --arg s "$status" \
    --arg t "$TIMESTAMP" \
    --arg lm "${last_msg:-}" \
    --argjson pid "$pid" \
    --argjson dc "$discord_connected" \
    '{
      status: $s,
      pid: $pid,
      discord_connected: $dc,
      last_message_at: (if $lm == "" then null else ($lm + "Z") end),
      last_checked_at: $t,
      last_red_event_at: null,
      details: null
    }'
}

# 3. Stub for not-deployed gateways
stub_not_deployed() {
  local details="$1"
  jq -n --arg t "$TIMESTAMP" --arg d "$details" \
    '{status:"not-deployed", last_checked_at:$t, details:$d}'
}

# 4. Probe each gateway
# Topher/Winnicot on GCP VM (systemd - Phase γ)
GCP_SSH="david_e_smith8@100.102.232.23"
TOPHER_PID=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$GCP_SSH" \
  "systemctl --user show openclaw-gateway@topher --property=MainPID --value 2>/dev/null" || echo "0")
if [ "$TOPHER_PID" != "0" ] && [ -n "$TOPHER_PID" ]; then
  TOPHER_WINNICOT=$(probe_gateway_systemd "topher-winnicot" "$GCP_SSH" "$TOPHER_PID" "/home/david_e_smith8/topher/.openclaw/logs/gateway.log")
else
  TOPHER_WINNICOT=$(jq -n --arg t "$TIMESTAMP" '{status:"down", pid:null, discord_connected:false, last_message_at:null, last_checked_at:$t, last_red_event_at:$t, details:"Systemd unit not running"}')
fi

# Cheryl/Switters on GCP VM (systemd)
# Use systemctl to get the PID reliably
CHERYL_PID=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$GCP_SSH" \
  "systemctl --user show openclaw-gateway@cheryl --property=MainPID --value 2>/dev/null" || echo "0")
if [ "$CHERYL_PID" != "0" ] && [ -n "$CHERYL_PID" ]; then
  CHERYL_SWITTERS=$(probe_gateway_systemd "cheryl-switters" "$GCP_SSH" "$CHERYL_PID" "/home/david_e_smith8/cheryl/.openclaw/logs/gateway.log")
else
  CHERYL_SWITTERS=$(jq -n --arg t "$TIMESTAMP" '{status:"down", pid:null, discord_connected:false, last_message_at:null, last_checked_at:$t, last_red_event_at:$t, details:"Systemd unit not running"}')
fi

# Bo is not deployed yet
BO_SKYWALKER=$(stub_not_deployed "Old-format config. See Phase β plan.")

# 5. Build status.json
jq -n \
  --arg t "$TIMESTAMP" \
  --argjson interval "$POLL_INTERVAL" \
  --argjson tw "$TOPHER_WINNICOT" \
  --argjson cs "$CHERYL_SWITTERS" \
  --argjson bs "$BO_SKYWALKER" \
  '{
    updated_at: $t,
    poll_interval_seconds: $interval,
    gateways: {
      "topher-winnicot": $tw,
      "cheryl-switters": $cs,
      "bo-skywalker": $bs
    },
    actions: [
      {name:"restart-topher-gateway", target:"topher-winnicot", workflow_url:"https://github.com/thtopher/th-fleet-dashboard/actions/workflows/restart-topher-gateway.yml", enabled:true},
      {name:"restart-cheryl-gateway", target:"cheryl-switters", workflow_url:"https://github.com/thtopher/th-fleet-dashboard/actions/workflows/restart-cheryl-gateway.yml", enabled:true},
      {name:"restart-bo-gateway", target:"bo-skywalker", workflow_url:"https://github.com/thtopher/th-fleet-dashboard/actions/workflows/restart-bo-gateway.yml", enabled:false}
    ]
  }' > docs/status.json.tmp

# 6. State-flip detection for Discord alerts
if [ -f docs/status.json ]; then
  for key in topher-winnicot cheryl-switters bo-skywalker; do
    prev=$(jq -r ".gateways[\"$key\"].status // \"\"" docs/status.json 2>/dev/null || echo "")
    curr=$(jq -r ".gateways[\"$key\"].status" docs/status.json.tmp)
    if [ -n "$prev" ] && [ "$prev" != "$curr" ]; then
      # Call Discord notification script if it exists and webhook is configured
      if [ -x scripts/notify-discord.sh ]; then
        bash scripts/notify-discord.sh "state-flip" "$key" "$prev" "$curr" || true
      fi
    fi
  done
fi

mv docs/status.json.tmp docs/status.json

# 7. Append to history.jsonl
jq -n -c \
  --arg type "poll" \
  --arg t "$TIMESTAMP" \
  --argjson tw "$TOPHER_WINNICOT" \
  --argjson cs "$CHERYL_SWITTERS" \
  --argjson bs "$BO_SKYWALKER" \
  '{type:$type, timestamp:$t, gateways:{"topher-winnicot":$tw,"cheryl-switters":$cs,"bo-skywalker":$bs}}' \
  >> docs/history.jsonl

# 8. Commit and push (silent if no changes)
git add docs/status.json docs/history.jsonl
if ! git diff --quiet --cached; then
  git -c user.name="fleet-poller" -c user.email="fleet-poller@thirdhorizon.local" \
    commit -m "status $TIMESTAMP" >/dev/null
  git push origin master >/dev/null 2>&1 || echo "[$(date -u +%FT%TZ)] push failed" >> "$REPO_DIR/poll.err"
fi
