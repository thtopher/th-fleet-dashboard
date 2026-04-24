# TH Fleet Dashboard

Live status dashboard for the Third Horizon agent fleet.

**Status:** MVP in development  
**Plan:** See [2026-04-24-feat-hermes-fleet-dashboard-mvp-plan.md](docs/plan-link.md)

## Quick Links

- **Dashboard:** https://thtopher.github.io/th-fleet-dashboard/
- **Actions:** https://github.com/thtopher/th-fleet-dashboard/actions

## Architecture

- Polling cron on Hostinger VPS writes `status.json` every 60s (business hours) / 5min (overnight)
- GitHub Pages serves static dashboard that reads `status.json`
- GitHub Actions workflows provide one-click restart for each gateway
- Discord alerts on state flips and action results

## Known Gaps

- **No process supervisor yet.** Gateways run under `nohup`. Systemd retrofit planned for Phase γ.
- **Stale-socket cause unverified.** Topher/Winnicot restarts every ~35min. Root cause hypothesized but not confirmed from OpenClaw source.
- **Cheryl and Bo not deployed.** Stub workflows return `not-deployed-yet`. Gateway bring-up planned for Phase β.

## Monitored Gateways

| Gateway | Host | Status |
|---------|------|--------|
| topher-winnicot | GCP th-agents-1 | Active |
| cheryl-switters | GCP th-agents-1 | Not deployed |
| bo-skywalker | GCP th-agents-1 | Not deployed |

---

*Maintained by Hermes (CDRO) under Topher's review.*
