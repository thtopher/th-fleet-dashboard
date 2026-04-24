# TH Fleet Dashboard

Live status dashboard for the Third Horizon agent fleet.

**Status:** ✅ Phase β In Progress  
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
2. Click `restart-topher-gateway` or `restart-cheryl-gateway`
3. Click "Run workflow"
4. Type `RESTART` in the confirmation field
5. Click "Run workflow" button
6. Wait ~5-25 seconds for completion

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
│   │  └─ poll.sh         │──── SSH ────► GCP VM (probe gateways)     │
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
│   └─────────────────────┘  (Phase γ: retrofit to systemd)           │
│                                                                      │
│   ┌─────────────────────┐                                           │
│   │  Cheryl/Switters    │  systemctl --user (openclaw-gateway@cheryl)│
│   │  openclaw-gateway   │  OPENCLAW_HOME=~/cheryl                   │
│   │  Port 18789         │  Log: ~/cheryl/.openclaw/logs/gateway.log │
│   └─────────────────────┘  ✅ LIVE (Phase β Gate 3)                 │
│                                                                      │
│   ┌─────────────────────┐                                           │
│   │  Bo/Skywalker       │  systemctl --user (openclaw-gateway@bo)   │
│   │  Port 18793         │  STAGED — awaiting Discord token from David│
│   └─────────────────────┘  ⏳ Blocked on Gate 4                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Monitored Gateways

| Gateway | Host | Port | Supervisor | Status | Restart Workflow |
|---------|------|------|------------|--------|------------------|
| Topher/Winnicot | GCP th-agents-1 | 18791 | screen (legacy) | ✅ Active | `restart-topher-gateway` |
| Cheryl/Switters | GCP th-agents-1 | 18789 | systemd | ✅ Active | `restart-cheryl-gateway` |
| Bo/Skywalker | GCP th-agents-1 | 18793 | systemd (staged) | ⏳ Awaiting David | Stub (exit 69) |

---

## Phase β Progress

| Gate | Description | Status |
|------|-------------|--------|
| 1 | Lingering bootstrap | ✅ Complete |
| 2 | Unit template + Cheryl dry run | ✅ Complete |
| 3 | Cheryl started, healthy, Discord connected | ✅ Complete |
| 4 | Bo config modernized | ⏳ Staged (awaiting David) |
| 5 | Bo started, healthy | ⏳ Blocked on Gate 4 |
| 6 | Dashboard wiring updated | ✅ Complete |

### Bo Setup Steps (for David)

To activate Bo's gateway, David needs to provide:

1. **Discord Bot Token** — Create application in Discord Developer Portal
2. **Discord Guild ID** — Bo's personal Discord server
3. **OpenRouter API Key** — Confirm Bo's key (or use shared org key)

Then on GCP VM:
```bash
# Edit ~/bo/.openclaw/openclaw.json and replace:
# - PLACEHOLDER-awaiting-david → actual Discord bot token
# - PLACEHOLDER-GUILD-ID → actual guild ID  
# - sk-or-PLACEHOLDER-bo-key → actual OpenRouter key

# Activate:
systemctl --user enable --now openclaw-gateway@bo
```

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

1. **Topher still under screen.** Phase γ will retrofit Topher to systemd.

2. **~35min health monitor restarts.** Topher self-restarts every ~35min due to OpenClaw's internal health monitor. Phase δ addresses this.

3. **Bo not activated.** Config staged but awaiting Discord credentials from David.

4. **CDN cache lag.** GitHub Pages has ~1-2 minute CDN cache.

5. **Discord webhook not configured.** State-flip alerts ready but webhook secret not set.

---

## Governance Gates (Phase β)

Per v3.1 IT Plan, Wave 1 go-live requires:

| # | Prerequisite | Status |
|---|--------------|--------|
| 1 | `governance/data-handling-floor.md` | ⏳ Target 2026-04-30 |
| 2 | Pilot-Phase AI Use Policy (Cheryl signed) | ⏳ Not drafted |
| 3 | Pilot-Phase AI Use Policy (Bo signed) | ⏳ Not drafted |
| 4 | BAA audit (Client Data Class Map) | ⏳ Not started |

**Cheryl's gateway is live for testing** but production use awaits governance prerequisites.

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
2. Check systemd: `systemctl --user status openclaw-gateway@cheryl`
3. Check logs: `tail -100 ~/cheryl/.openclaw/logs/gateway.log`

### Cheryl restart (systemd)
```bash
ssh david_e_smith8@100.102.232.23 "systemctl --user restart openclaw-gateway@cheryl"
```

### Topher restart (screen — legacy)
```bash
ssh david_e_smith8@100.102.232.23 "screen -S topher-gateway -X quit; screen -dmS topher-gateway bash -c 'cd ~/topher && OPENCLAW_HOME=~/topher openclaw gateway >> /tmp/topher-gateway.log 2>&1'"
```

---

## References

- Phase α plan: Fleet Dashboard MVP
- Phase β plan: Cheryl and Bo gateway bring-up
- Phase γ plan: Topher systemd retrofit (to be written)
- Phase δ plan: Stale-socket fix (to be written)

*Maintained by Hermes (CDRO) under Topher's review.*
