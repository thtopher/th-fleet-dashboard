# Fleet Dashboard MVP - Progress Checkpoint

**Date:** 2026-04-24 17:30 UTC  
**Context:** Saved for context window continuation

---

## Completed Gates

### ✅ Gate 1: Repo Created, Pages Enabled
- Repo: https://github.com/thtopher/th-fleet-dashboard
- Pages: https://thtopher.github.io/th-fleet-dashboard/
- Skeleton committed with sample status.json

### ✅ Gate 2: Poller Script Written & Tested
- `scripts/poll.sh` - probes Topher gateway via SSH to GCP VM
- `scripts/notify-discord.sh` - sends state-flip alerts
- Manual test confirmed: Topher shows status=up, pid detected, discord_connected=true

### ✅ Gate 3: Dashboard Renders Correctly
- Fresh data → clean display, green dot for Topher, gray for Cheryl/Bo
- Stale data (>120s) → red banner with message, all rows show "Unknown"
- CSS fix applied for hidden attribute (`style.css?v=2`)

### ✅ Gate 4: Cron Enabled (SOAKING)
- Crontab entry: `* * * * * /bin/bash /home/david/th-fleet-dashboard/scripts/poll.sh >> /home/david/th-fleet-dashboard/poll.log 2>&1`
- Polls running every minute successfully
- history.jsonl growing, commits landing
- No errors in poll.log

### 🔄 Gate 5: Restart Workflow (IN PROGRESS)
**Status:** SSH auth working, but restart script hangs on nohup

**Problem:** The SSH command to start the gateway doesn't release:
```bash
ssh "$GCP_VM" "cd $GATEWAY_DIR && OPENCLAW_HOME=$GATEWAY_DIR nohup openclaw gateway >> $LOG_PATH 2>&1 &"
```

**Attempted fixes:**
1. Added `</dev/null` - still hangs
2. Added `disown` - still hangs  
3. Added `setsid nohup ... < /dev/null &` - still hangs

**Next step:** Need to fix the SSH detach issue. Options:
- Use `screen -dm` or `tmux` to launch
- Write a helper script on GCP VM that launches and exits
- Use `at now` to schedule immediate background job

---

## Files Created

### Repository Structure
```
th-fleet-dashboard/
├── README.md
├── .gitignore (poll.log, poll.err)
├── docs/
│   ├── index.html
│   ├── style.css (v2 - hidden attr fix)
│   ├── app.js
│   ├── status.json (updated by cron)
│   └── history.jsonl (append-only)
├── scripts/
│   ├── poll.sh (working)
│   ├── notify-discord.sh (working)
│   ├── restart-topher-gateway.sh (NEEDS FIX - hangs)
│   ├── restart-cheryl-gateway.sh (stub, exit 69)
│   └── restart-bo-gateway.sh (stub, exit 69)
└── .github/workflows/
    ├── restart-topher-gateway.yml
    ├── restart-cheryl-gateway.yml
    └── restart-bo-gateway.yml
```

---

## GitHub Secrets Configured
- `HOSTINGER_SSH_KEY` ✅ (fleet-dashboard key)
- `HOSTINGER_HOST` ✅ (2.24.193.160)
- `HOSTINGER_USER` ✅ (david)
- `DISCORD_OPS_WEBHOOK` - NOT YET CONFIGURED

---

## SSH Keys
- `/home/david/.ssh/fleet-dashboard` - deploy key for GitHub Actions
- Public key added to `/home/david/.ssh/authorized_keys`
- Topher's key also added to authorized_keys

---

## Key Technical Details

### Topher Gateway on GCP VM
- Host: `david_e_smith8@100.102.232.23` (Tailscale)
- External IP: `34.122.2.114`
- Gateway dir: `/home/david_e_smith8/topher`
- Log path: `/tmp/topher-gateway.log`
- Process pattern: `openclaw-gateway`
- OPENCLAW_HOME: `/home/david_e_smith8/topher`

### Current Gateway PID
- Was: 256152 (before restart attempts)
- After restart attempts: 316141 (or newer)

### Poll Interval Logic
- Business hours (7 AM - 11 PM CT): 60 seconds
- Overnight: 300 seconds (5 min)

---

## Remaining Work

### Gate 5 (Current)
1. Fix restart-topher-gateway.sh to properly detach the process
2. Test workflow end-to-end
3. Verify history.jsonl gets action event
4. Verify Discord notification (once webhook configured)

### Gate 6: Stub Workflows
- Already created, just need to test they return exit 69

### Gate 7: Discord Alerts End-to-End
- Need DISCORD_OPS_WEBHOOK secret
- Test state-flip by killing Topher gateway

### Gate 8: MVP Handoff
- Update README with usage instructions
- Document known gaps
- Get Topher sign-off

---

## Commands to Resume

```bash
# Check cron is still running
cd /home/david/th-fleet-dashboard
wc -l docs/history.jsonl
git log --oneline -5

# Check Topher gateway status
ssh david_e_smith8@100.102.232.23 "pgrep -fa openclaw"

# Test restart script (after fixing)
timeout 30 bash scripts/restart-topher-gateway.sh

# Trigger workflow
export PATH="$HOME/.local/bin:$PATH"
gh workflow run restart-topher-gateway.yml -f confirm=RESTART
gh run list --workflow=restart-topher-gateway.yml --limit 1
```

---

## Plan Reference
Full plan at: `/home/david/.hermes/cache/documents/doc_32a0efda1f1d_2026-04-24-feat-hermes-fleet-dashboard-mvp-plan.md`
