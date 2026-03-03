# Homelab Auditor

AI-powered infrastructure auditor for homelab. Combines deterministic evidence collection with exploratory AI auditing via Claude Code.

## How It Works

The auditor runs on **LXC 504 (dev-monitoring)** and monitors the homelab through SSH access to infrastructure hosts. It operates in three layers:

1. **Evidence Collection** (weekly) — Lynis scans, Trivy vulnerability scans, system snapshots
2. **Signal Collection** (every 6h) — Uptime Kuma status, Docker events (die, oom)
3. **Audit Sweeps** (on-demand or scheduled) — Claude Code analyzes evidence/signals, SSHes into hosts, writes findings

## Quick Start

```bash
# Interactive audit session
cd ~/repos/homelab-auditor
claude --dangerously-skip-permissions

# Or use the alias
audit

# Full automated sweep
audit-sweep
audit-sweep "Focus on network security"
```

## Project Structure

```
homelab-auditor/
├── CLAUDE.md                  # Infrastructure knowledge + audit protocol
├── .claude/
│   ├── settings.json          # Claude permissions
│   └── agents/                # Specialist audit agents
│       ├── audit-orchestrator.md
│       ├── homelab-reliability-auditor.md
│       ├── homelab-network-engineer.md
│       ├── homelab-container-ops.md
│       ├── homelab-observability-builder.md
│       └── homelab-research-coordinator.md
├── .agent/
│   └── rules/
│       └── 001-auditor-standards.md
├── scripts/
│   ├── evidence-collect.sh    # Weekly evidence collection (systemd timer)
│   ├── signal-collect.sh      # 6h signal collection (systemd timer)
│   └── audit-sweep.sh         # Claude headless sweep trigger
├── seed/
│   ├── coverage-map.json      # 28-area coverage map (initial seed)
│   └── backlog.json           # Initial backlog items
└── README.md
```

## Data Layout (on LXC 504)

Audit data lives outside the repo at `/opt/auditor/`:

```
/opt/auditor/
├── evidence/       # Lynis, Trivy, snapshots (by date)
├── signals/        # Uptime Kuma, Docker events (daily JSON)
├── journal/        # Audit session logs
├── coverage/       # Coverage map (what areas checked, when)
├── backlog/        # Items to investigate
├── findings/       # Audit findings (issues found)
├── reports/        # Full sweep reports
└── logs/           # Script logs
```

## Agents

| Agent | Purpose |
|-------|---------|
| `audit-orchestrator` | Coordinates audit sessions, manages coverage state |
| `homelab-reliability-auditor` | Deep reliability analysis, incident playbooks |
| `homelab-network-engineer` | Network diagnostics, VLAN/firewall analysis |
| `homelab-container-ops` | Docker/LXC troubleshooting, optimization |
| `homelab-observability-builder` | Monitoring gaps, alerting, SLO analysis |
| `homelab-research-coordinator` | Technology research, best practices |

## Infrastructure (managed by HQ repo)

The following are deployed via Ansible (`Voytek1980/HQ`), not this repo:

- Directory creation (`/opt/auditor/...`)
- Tool installation (Lynis, Trivy)
- SSH config (inter-container access)
- Systemd timers (evidence-collect, signal-collect)
- Logrotate configuration

## Development

Edit files directly in this repo. Changes take effect immediately for interactive sessions (`audit`). For automated sweeps, the systemd timers use symlinked scripts from `~/bin/` pointing to this repo.

No CI/CD pipeline — this is an operational tool, not deployed software.
