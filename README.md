# TH Fleet Dashboard

Live status dashboard for the Third Horizon agent fleet.

**Status:** ✅ MVP Complete  
**Dashboard:** https://thtopher.github.io/th-fleet-dashboard/  
**Actions:** https://github.com/thtopher/th-fleet-dashboard/actions

---

## Quick Start

### View Status
Open https://thtopher.github.io/th-fleet-dashboard/

- **Green dot** = Gateway up and healthy
- **Gray dot** = Not deployed yet
- **Red banner** = Poller stale (Hostinger cron may be down)

### Restart a Gateway
1. Go to [Actions](https://github.com/thtopher/th-fleet-dashboard/actions)
2. Click `restart-topher-gateway` (or other gateway)
3. Click "Run workflow"
4. Type `RESTART` in the confirmation field
5. Click "Run workflow" button
6. Wait ~25 seconds for completion

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub Pages                                 │
│                 https://thtopher.github.io/th-fleet-dashboard/       │
│                                                                      │
│   ┌─────────────┐    fetches     ┌─────────────────┐                │
│   │  Browser    │ ─────────────► │  status.json    │                │
│   │  (app.js)   │   every 30s    │  (updated by    │                │
│   └─────────────┘                │   cron poller)  │                │
│                                  └─────────────────┘                │
└─────────────────────────────────────────────────────────────────────┘
                                         ▲
                                         │ git push
                                         │
┌─────────────────────────────────────────────────────────────────────┐
│                    Hostinger VPS (2.24.193.160)                      │
│                                                                      │
│   ┌─────────────────────┐                                           │
│   │  cron (every 1m)    │                                           │
│   │  └─ poll.sh         │──── SSH ────► GCP VM (probe gateway)      │
│   │     └─ status.json  │                                           │
│   │     └─ history.jsonl│                                           │
│   └─────────────────────┘                                           │
│                                                                      │
│   ┌─────────────────────┐                                           │
│   │  restart-*.sh       │──── SSH ────► GCP VM (restart gateway)    │
│   │  (called by GH      │                                           │
│   │   Actions)          │                                           │
│   └─────────────────────┘                                           │
└─────────────────────────────────────────────────────────────────────┘
                                         ▲
                                         │ SSH
                                         │
┌─────────────────────────────────────────────────────────────────────┐
│                   GCP VM th-agents-1 (100.102.232.23)                │
│                                                                      │
│   ┌─────────────────────┐                                           │
│   │  Topher/Winnicot    │  screen -dmS topher-gateway               │
│   │  openclaw-gateway   │  OPENCLAW_HOME=~/topher                   │
│   │  Port 18791         │  Log: /tmp/topher-gateway.log             │
│   └─────────────────────┘                                           │
│                                                                      │
│   ┌─────────────────────┐                                           │
│   │  Cheryl/Switters    │  NOT DEPLOYED (Phase β)                   │
│   │  Port 18792         │                                           │
│   └─────────────────────┘                                           │
│                                                                      │
│   ┌─────────────────────┐                                           │
│   │  Bo/Skywalker       │  NOT DEPLOYED (Phase β)                   │
│   │  Port TBD           │                                           │
│   └─────────────────────┘                                           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Monitored Gateways

| Gateway | Host | Port | Status | Restart Workflow |
|---------|------|------|--------|------------------|
| Topher/Winnicot | GCP th-agents-1 | 18791 | ✅ Active | `restart-topher-gateway` |
| Cheryl/Switters | GCP th-agents-1 | 18792 | ⏳ Not deployed | Stub (exit 69) |
| Bo/Skywalker | GCP th-agents-1 | TBD | ⏳ Not deployed | Stub (exit 69) |

---

## Files

| File | Purpose |
|------|---------|
| `docs/status.json` | Current gateway status (updated every 60s by cron) |
| `docs/history.jsonl` | Append-only log of all poll and action events |
| `scripts/poll.sh` | Cron job that probes gateways and updates status |
| `scripts/restart-*.sh` | Restart scripts (called by GitHub Actions) |
| `.github/workflows/restart-*.yml` | GitHub Actions for one-click restart |

---

## GitHub Secrets Required

| Secret | Value |
|--------|-------|
| `HOSTINGER_SSH_KEY` | Ed25519 private key for `david@2.24.193.160` |
| `HOSTINGER_HOST` | `2.24.193.160` |
| `HOSTINGER_USER` | `david` |
| `DISCORD_OPS_WEBHOOK` | *(Optional)* Discord webhook for alerts |

---

## Known Gaps

1. **No process supervisor.** Gateways run under `screen -dm`. Systemd retrofit planned for Phase γ.

2. **~35min health monitor restarts.** Topher/Winnicot self-restarts every ~35min due to OpenClaw's internal health monitor detecting idle websockets. Root cause understood but config fix not yet applied.

3. **Cheryl and Bo not deployed.** Gateway configs exist but processes not started. Phase β.

4. **CDN cache lag.** GitHub Pages has ~1-2 minute CDN cache. Dashboard may show slightly stale data.

5. **Discord webhook not configured.** State-flip alerts ready but webhook secret not set.

---

## Cron Schedule

- **Business hours (7 AM - 11 PM CT):** Every 60 seconds
- **Overnight (11 PM - 7 AM CT):** Every 5 minutes

Crontab entry on Hostinger VPS:
```
* * * * * /bin/bash /home/david/th-fleet-dashboard/scripts/poll.sh >> /home/david/th-fleet-dashboard/poll.log 2>&1
```

---

## Troubleshooting

### Dashboard shows red "poller may be down" banner
1. SSH to Hostinger: `ssh david@2.24.193.160`
2. Check cron: `crontab -l | grep fleet`
3. Check poll.log: `tail -50 /home/david/th-fleet-dashboard/poll.log`
4. Run poll manually: `bash /home/david/th-fleet-dashboard/scripts/poll.sh`

### Restart workflow fails
1. Check Actions log for SSH errors
2. Verify secrets are configured correctly
3. Test SSH manually: `ssh david@2.24.193.160 "echo ok"`

### Gateway shows "down" but should be up
1. SSH to GCP: `ssh david_e_smith8@100.102.232.23`
2. Check process: `pgrep -fa openclaw`
3. Check logs: `tail -100 /tmp/topher-gateway.log`

---

*Maintained by Hermes (CDRO) under Topher's review.*
