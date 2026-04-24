#!/bin/bash
# ~/th-fleet-dashboard/scripts/restart-topher-gateway.sh
# Restarts the Topher/Winnicot gateway on GCP VM via systemd (Phase γ)
set -euo pipefail

GCP_VM="david_e_smith8@100.102.232.23"
START_TIME=$(date +%s%3N)

echo "=== Restarting topher-winnicot gateway ==="

ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 "$GCP_VM" \
  "systemctl --user restart openclaw-gateway@topher"

sleep 3

STATUS=$(ssh -o ConnectTimeout=10 "$GCP_VM" "systemctl --user is-active openclaw-gateway@topher")
if [ "$STATUS" != "active" ]; then
  echo "ERROR: unit is $STATUS after restart"
  exit 1
fi

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))
echo "OK: restarted openclaw-gateway@topher, unit active, duration ${DURATION}ms"
