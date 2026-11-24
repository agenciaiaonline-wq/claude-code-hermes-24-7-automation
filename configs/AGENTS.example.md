# AGENTS.md — Hermes 24/7 Operational Governance (Sanitized Example)

## 1. System Topology
- **Gateway:** OmniRoute on `http://127.0.0.1:20128/v1` (`omniroute.service`)
- **Executor:** Claude Code CLI (`claude -p`) for multi-file software builds & media rendering
- **Automation:** Self-hosted `n8n` + `PostgreSQL 16` + `Redis 7` + `WAHA` + `Qdrant`

## 2. Hardware & Concurrency Guardrails
- On compact 2 vCPU / 4 GB RAM hosts:
  - Hard ceiling of **2 to 3 concurrent lightweight subagents**.
  - Keep Linux load average `< 2.5` and available RAM `> 400 MiB`.
  - Throttle background tasks immediately if free RAM falls below threshold.

## 3. Browser & Tab Hygiene (Playwright / CDP)
- Operate strictly within **one browser window** (`DISPLAY=:10` on Linux, `WinSta0\Default` on Windows).
- Deduplicate tabs: inspect open tabs via `browser_tabs(list)` before navigating to avoid opening the same dashboard twice.
- Close temporary OAuth/lookup tabs immediately upon completion (`1–2` tabs max).
- Preserve the native OS cursor; never inject synthetic overlay cursors.

## 4. OAuth Account Governance (Placeholder Example)
- Use only the single designated agency automation account during OAuth sign-in flows:
  - Name: `Agency Automation Operator`
  - Email: `agency@example.com`

## 5. Safety & Human Approval Gates
- Never commit or output `.env` secrets, API tokens, or private client PII.
- Require explicit operator review (`needs_review`) before sending unsolicited outbound campaigns, triggering payments, or deploying destructive infrastructure changes.
