#!/bin/bash
# ~/th-fleet-dashboard/scripts/restart-topher-gateway.sh
# Runs on the Hostinger VPS via SSH from GitHub Actions.
# Restarts the Topher/Winnicot gateway on the GCP VM.
set -euo pipefail

GCP_VM="david_e_smith8@100.102.232.23"
GATEWAY_DIR="/home/david_e_smith8/topher"
PROC_PATTERN="openclaw-gateway"
LOG_PATH="/tmp/topher-gateway.log"

START_TIME=$(date +%s%3N)

echo "=== Restarting topher-winnicot gateway ==="

# 1. Find and terminate existing process (if any)
PID=$(ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 "$GCP_VM" pgrep -f "$PROC_PATTERN" 2>/dev/null | head -n1 || true)
if [ -n "$PID" ]; then
  echo "Terminating existing PID $PID"
  ssh "$GCP_VM" "kill $PID" || true
  sleep 2
  # Force kill if still running
  ssh "$GCP_VM" "kill -9 $PID 2>/dev/null" || true
  sleep 1
fi

# 2. Start new instance under nohup
echo "Starting new gateway instance..."
ssh "$GCP_VM" "cd $GATEWAY_DIR && OPENCLAW_HOME=$GATEWAY_DIR nohup openclaw gateway >> $LOG_PATH 2>&1 &"
sleep 5

# 3. Verify new PID is alive
NEW_PID=$(ssh "$GCP_VM" pgrep -f "$PROC_PATTERN" | head -n1 || true)
if [ -z "$NEW_PID" ]; then
  echo "ERROR: gateway failed to stay alive after restart"
  exit 1
fi

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))

echo "OK: restarted topher-winnicot, new PID $NEW_PID, duration ${DURATION}ms"
