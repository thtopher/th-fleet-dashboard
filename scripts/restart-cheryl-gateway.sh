#!/bin/bash
# ~/th-fleet-dashboard/scripts/restart-cheryl-gateway.sh
# Restarts the Cheryl/Switters gateway on GCP VM via systemd
set -euo pipefail

GCP_VM="david_e_smith8@100.102.232.23"
START_TIME=$(date +%s%3N)

echo "=== Restarting cheryl-switters gateway ==="

ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 "$GCP_VM" \
  "systemctl --user restart openclaw-gateway@cheryl"

sleep 3

STATUS=$(ssh -o ConnectTimeout=10 "$GCP_VM" "systemctl --user is-active openclaw-gateway@cheryl")
if [ "$STATUS" != "active" ]; then
  echo "ERROR: unit is $STATUS after restart"
  exit 1
fi

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))
echo "OK: restarted openclaw-gateway@cheryl, unit active, duration ${DURATION}ms"
