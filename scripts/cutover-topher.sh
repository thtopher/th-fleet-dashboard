#!/bin/bash
# One-time cutover: stop Topher's screen/nohup process, start systemd instance.
# Run from the Hostinger VPS.
set -euo pipefail

GCP_VM="david_e_smith8@100.102.232.23"

echo "=== Phase γ Cutover: Topher to systemd ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo -e "\nStep 1: Find existing screen/nohup PID"
# Kill the screen session, which will kill the child processes
SCREEN_PID=$(ssh -o ConnectTimeout=10 "$GCP_VM" "pgrep -f 'SCREEN.*topher-gateway'" || true)
OPENCLAW_PID=$(ssh -o ConnectTimeout=10 "$GCP_VM" "pgrep -f 'openclaw.*topher' | grep -v SCREEN | head -n1" || true)
echo "Screen PID: ${SCREEN_PID:-none}"
echo "OpenClaw PID: ${OPENCLAW_PID:-none}"

echo -e "\nStep 2: Stop screen session (kills child processes)"
ssh -o ConnectTimeout=10 "$GCP_VM" "screen -S topher-gateway -X quit 2>/dev/null" || true
sleep 2

# Also kill any orphaned openclaw processes for topher
if [ -n "$OPENCLAW_PID" ]; then
  echo "Killing orphaned OpenClaw process $OPENCLAW_PID"
  ssh -o ConnectTimeout=10 "$GCP_VM" "kill $OPENCLAW_PID 2>/dev/null" || true
  sleep 2
  ssh -o ConnectTimeout=10 "$GCP_VM" "kill -9 $OPENCLAW_PID 2>/dev/null" || true
fi

echo -e "\nStep 3: Confirm no stale process"
STILL=$(ssh -o ConnectTimeout=10 "$GCP_VM" "pgrep -f 'openclaw.*topher' | grep -v SCREEN" || true)
if [ -n "$STILL" ]; then
  echo "WARNING: Process $STILL still running, force killing..."
  ssh -o ConnectTimeout=10 "$GCP_VM" "kill -9 $STILL" || true
  sleep 1
fi

# Final check
STILL2=$(ssh -o ConnectTimeout=10 "$GCP_VM" "pgrep -f 'openclaw.*topher' | grep -v SCREEN" || true)
if [ -n "$STILL2" ]; then
  echo "ERROR: Process $STILL2 still running; abort" >&2
  echo "Rollback: ssh $GCP_VM 'screen -dmS topher-gateway bash -c \"cd ~/topher && OPENCLAW_HOME=~/topher openclaw gateway >> /tmp/topher-gateway.log 2>&1\"'"
  exit 1
fi
echo "No stale Topher processes."

echo -e "\nStep 4: Start systemd unit"
ssh -o ConnectTimeout=10 "$GCP_VM" "systemctl --user start openclaw-gateway@topher"
sleep 5

echo -e "\nStep 5: Verify unit is active"
STATUS=$(ssh -o ConnectTimeout=10 "$GCP_VM" "systemctl --user is-active openclaw-gateway@topher")
if [ "$STATUS" != "active" ]; then
  echo "ERROR: unit is $STATUS" >&2
  echo ""
  echo "=== ROLLBACK INSTRUCTIONS ==="
  echo "Run on GCP VM:"
  echo "  screen -dmS topher-gateway bash -c 'cd ~/topher && OPENCLAW_HOME=~/topher openclaw gateway >> /tmp/topher-gateway.log 2>&1'"
  exit 1
fi

NEW_PID=$(ssh -o ConnectTimeout=10 "$GCP_VM" "systemctl --user show openclaw-gateway@topher --property=MainPID --value")
echo "Unit is active. New PID: $NEW_PID"

echo -e "\nStep 6: Verify Discord connection (check logs)"
sleep 3
ssh -o ConnectTimeout=10 "$GCP_VM" "tail -20 ~/topher/.openclaw/logs/gateway.log 2>/dev/null" || echo "Log not yet populated"

echo -e "\n=== CUTOVER COMPLETE ==="
echo "Topher/Winnicot is now running under systemd"
echo "PID: $NEW_PID"
echo "Unit: openclaw-gateway@topher.service"
