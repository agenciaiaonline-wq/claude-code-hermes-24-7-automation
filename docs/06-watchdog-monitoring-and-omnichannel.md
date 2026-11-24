# Step 06 — 24/7 Watchdog, Task Bridge & Omnichannel Docker Stack

To guarantee uninterrupted 24/7 execution across restarts, OOM spikes, and incoming client requests, this stack combines a **1-minute Watchdog daemon**, a **zero-dependency Task Bridge**, a **Telegram Command Center**, and a **self-hosted Docker core**.

---

## 1. Self-Hosted Docker Core (`docker/docker-compose.example.yml`)

Running your own orchestration and CRM database stack eliminates costly SaaS task limits (often cutting recurring software bills by **70–80%**):

| Service | Container | Purpose | Bound Port (Loopback) |
| :--- | :--- | :--- | :--- |
| **PostgreSQL 16** | `agency_postgres` | Leads, proposals, projects & worker DAG | `127.0.0.1:5433` |
| **Redis 7** | `agency_redis` | Sub-ms conversational state & message debounce | `127.0.0.1:6380` |
| **n8n Community** | `agency_n8n` | Unlimited workflow & webhook orchestration | `127.0.0.1:5678` |
| **WAHA** | `agency_waha` | Direct WhatsApp HTTP API + Webhook events | `127.0.0.1:3000` |
| **Qdrant** | `agency_qdrant` | Hybrid vector store for private RAG pipelines | `127.0.0.1:6333` |

Launch with:
```bash
cp configs/.env.example .env
docker compose -f docker/docker-compose.example.yml --env-file .env up -d
```

---

## 2. Automatic HTTPS Reverse Proxy (`Caddy`)

Never expose internal ports publicly. Terminate TLS automatically with Caddy ([`configs/Caddyfile.example`](../configs/Caddyfile.example)):

```caddyfile
omniroute.your-domain.example.com {
    reverse_proxy 127.0.0.1:20128
}

n8n.your-domain.example.com {
    reverse_proxy 127.0.0.1:5678 {
        flush_interval -1
    }
}
```
> [!IMPORTANT]
> For WebSocket-heavy dashboards (like n8n or Hermes Web UI), ensure `flush_interval -1` and standard `Upgrade` / `Connection` headers are preserved so connections do not drop with WebSocket code `1006`.

---

## 3. HTTP-to-Tmux Task Bridge (`scripts/hermes_task_bridge.py`)

[`scripts/hermes_task_bridge.py`](../scripts/hermes_task_bridge.py) uses only Python's standard library (`http.server`) on port `5050` so n8n workflows, webhooks, or Telegram bots can dispatch structured tasks directly into the running `hermes-agent` session and log every dispatch to `dispatched_tasks.jsonl`:

```bash
# Test dispatching a task locally
curl -X POST http://127.0.0.1:5050/api/task \
  -H "Content-Type: application/json" \
  -d '{"client": "demo-lead", "task": "Audit landing page SEO and prepare summary"}'
```

---

## 4. 24/7 Watchdog & Hardware Guardian (`scripts/hermes_watchdog.example.sh`)

Hermes Gateway includes an internal `loop_watchdog` that intentionally exits with code `75` if the event loop deadlocks. Running inside a plain `tmux` session without an external supervisor means a wedged process stays dead until manual intervention.

[`scripts/hermes_watchdog.example.sh`](../scripts/hermes_watchdog.example.sh) runs every 60 seconds via cron (`* * * * *`):
1. Probes `http://127.0.0.1:20128/health` -> restarts `omniroute.service` if down.
2. Checks `docker ps` -> revives any stopped core container (`postgres`, `redis`, `n8n`, `waha`, `qdrant`).
3. Checks `tmux has-session -t hermes-agent` (or systemd unit `hermes-agent.service`) -> respawns automatically if terminated.
4. Probes `http://127.0.0.1:5050/health` -> restarts `hermes_task_bridge.py` if down.
5. **Strict `<400 MiB` RAM Protection:** When available memory drops below `400 MiB`, clears safe page caches and prunes leaked `chrome-sandbox` zombies before Linux OOM kills PostgreSQL or OmniRoute.

---

## Next Step
Proceed to **[07 — Production Troubleshooting Runbook](07-troubleshooting-runbook.md)**.
