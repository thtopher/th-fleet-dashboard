#!/bin/bash
# ~/th-fleet-dashboard/scripts/restart-bo-gateway.sh
# Stub: Bo/Skywalker gateway is staged but not activated
set -euo pipefail

echo "BLOCKED: bo-skywalker gateway is staged but not activated."
echo ""
echo "Placeholders awaiting David:"
echo "  - DISCORD_BOT_TOKEN"
echo "  - Discord Guild ID"
echo "  - OpenRouter API key confirmation"
echo ""
echo "Once David provides these, update ~/bo/.openclaw/openclaw.json on GCP VM,"
echo "then run: systemctl --user enable --now openclaw-gateway@bo"
echo ""
echo "See Phase β plan for details."
exit 69  # EX_UNAVAILABLE
