# Step 02 — OmniRoute AI Gateway & Multi-Provider Auto-Failover

[**OmniRoute**](https://github.com/cheaper-inference/OmniRoute) is the central inference router in this architecture. It consolidates multiple AI providers (Anthropic, OpenAI, Gemini, OpenRouter, OAuth pools, and local Ollama models) behind a single local OpenAI/Anthropic-compatible endpoint on **`http://127.0.0.1:20128/v1`**.

---

## 1. Critical Rule: Always Use `127.0.0.1`, Never `localhost`

On Ubuntu Linux and dual-stack Windows systems, `localhost` frequently resolves to IPv6 (`::1`) while Node.js gateways bind to IPv4 (`127.0.0.1`), triggering intermittent `ECONNREFUSED` failures inside agent loops.

- Always set **`http://127.0.0.1:20128/v1`** in `ANTHROPIC_BASE_URL`, `OPENAI_BASE_URL`, `config.yaml`, and `settings.json`.

---

## 2. Installation & Systemd Persistence

```bash
# Install OmniRoute globally
npm install -g omniroute

# Verify installation
omniroute --version
```

Create a systemd unit using the sanitized template [`systemd/omniroute.service.example`](../systemd/omniroute.service.example):

```bash
sudo cp systemd/omniroute.service.example /etc/systemd/system/omniroute.service
sudo systemctl daemon-reload
sudo systemctl enable --now omniroute
```

Check health:
```bash
curl -s http://127.0.0.1:20128/health
```

---

## 3. Environment Hardening for 24/7 Multi-Account Stability

When operating multiple OAuth or API connections under 24/7 traffic, naive parallel health checks trigger `429 RATE_LIMITED` storms or cascade failures across healthy accounts. Add these proven variables to `~/.omniroute/.env` (see [`configs/.env.example`](../configs/.env.example)):

```env
# Serialize proactive health checks (1 account at a time)
HEALTHCHECK_BATCH_SIZE=1
HEALTHCHECK_STAGGER_MS=5000
HEALTHCHECK_JITTER_MIN_MS=1500
HEALTHCHECK_JITTER_MAX_MS=6000

# Space out quota polling to prevent burst rate limits
PROVIDER_LIMITS_SYNC_INTERVAL_MINUTES=120
PROVIDER_LIMITS_SYNC_SPACING_MS=4000
OMNIROUTE_QUOTA_FETCH_MIN_INTERVAL_MS=1500
OMNIROUTE_QUOTA_FETCH_JITTER_MS=1000
CREDENTIAL_HEALTH_CHECK_INTERVAL=21600000

# Node heap ceiling for large SQLite call-log workloads
NODE_OPTIONS=--max-old-space-size=2048
```

### Per-Connection Circuit Breaker
Configure OmniRoute's `resilienceSettings` so a single expired or restricted OAuth connection is isolated without poisoning the entire provider pool:
```json
{
  "tokenRefreshBreaker": {
    "scope": "connection",
    "failureThreshold": 5,
    "cooldownMs": 1800000
  }
}
```

---

## 4. Designing Smart Combos for Coding & Autonomous Agents

> [!IMPORTANT]
> **Tool-Calling & Context Window Requirement:**
> Agents like Hermes send ~25 tool definitions (~16,000+ prompt tokens) on turn 1, and Claude Code sends large tool schemas plus workspace context. Placing pure-text web chat models (without function calling or with `<128k` context) at the top of an agent combo causes immediate `HTTP 400` errors and cascade fallbacks.

### Recommended Combo Tiers
1. **`auto-coding-elite`** *(used by Claude Code executor)*:
   - Tier 1: High-reasoning coding model (`claude-opus-4-6-thinking` / `claude-sonnet-4-6`, 200k context, tools verified)
   - Tier 2: High-context fallback (`gemini-3.8-flash-high` or `gpt-5.x`, 128k–1M context, tools verified)
   - Tier 3: OpenRouter / API key resilient backup
2. **`auto-omni-resilient`** *(used by Hermes 24/7 orchestrator)*:
   - Fast tool-calling primary (`claude-sonnet-4-6` / `gemini-3.8-flash-high`)
   - Secondary tool-calling provider (`openai-codex` / OpenRouter free tool-capable tier)
   - Local offline safety net (`ollama-local/qwen2.5-coder:1.5b` or `7b`)

---

## 5. Unified Protocol Support & SQLite Maintenance

Ensure your gateway supports all three client formats seamlessly:
- `POST /v1/messages` — **Anthropic Messages API** (Claude Code CLI)
- `POST /v1/chat/completions` — **OpenAI Chat Completions** (Hermes Agent, n8n, LangChain)
- `POST /v1/responses` — **OpenAI Responses API** (Codex / newer agent runtimes)

### Periodic SQLite Maintenance
OmniRoute stores call logs and routing state in `~/.omniroute/storage.sqlite`. Enable WAL mode, back up safely using SQLite's `.backup()` API (never raw `cp` during writes), and periodically prune old `call_logs` + run `VACUUM;` so the database stays fast (`<300 MB`) instead of growing past `1.5 GB`.

---

## Next Step
Proceed to **[03 — Claude Code CLI & Project Executor Integration](03-claude-code-integration.md)**.
