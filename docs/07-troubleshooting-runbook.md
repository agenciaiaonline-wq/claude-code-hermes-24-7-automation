# Step 07 — Production Troubleshooting Runbook

Every failure mode documented below was observed and resolved during 24/7 operation across Linux VPS and Windows hosts.

---

## 1. `HTTP 400` Cascade When Launching Hermes or Claude Code
- **Root Cause A:** A pure-text web model (without function calling / tool schemas, or `<128k` context window) was placed at the top of the OmniRoute combo. Hermes sends ~25 tool schemas (~16k tokens) on turn 1.
  - **Fix:** Ensure every candidate at the top of `auto-omni-resilient` and `auto-coding-elite` supports tool calling and `>=128k` context.
- **Root Cause B:** The OmniRoute API key has `model_access_mode = 'restricted'` or a locked `forced_model`.
  - **Fix:** Set `model_access_mode = 'all'`, `forced_model = NULL`, and include `"combo/*"` in `allowed_combos` so `/model` switching works freely.

## 2. `HTTP 403` OAuth / Plan Gating Errors Across Accounts
- **Root Cause:** A single account in a multi-account OAuth pool hits verification (`403`) or lacks access to a tier-restricted model (e.g., an Ultra-only model), poisoning the shared refresh circuit breaker.
- **Fix:** Configure `tokenRefreshBreaker.scope = "connection"`, serialize health checks (`HEALTHCHECK_BATCH_SIZE=1`, `HEALTHCHECK_STAGGER_MS=5000`), and explicitly exclude tier-locked models on non-eligible connections rather than hiding them globally.

## 3. `ECONNREFUSED ::1:20128` on Ubuntu or Windows
- **Root Cause:** `localhost` resolved to IPv6 `::1` while the local gateway bound to IPv4 `127.0.0.1`.
- **Fix:** Hardcode **`http://127.0.0.1:20128/v1`** everywhere (`settings.json`, `config.yaml`, `~/.bashrc`, n8n HTTP nodes).

## 4. `SQLite database is locked` Under Multi-Worker Concurrency
- **Root Cause:** Running 4+ concurrent Hermes worker processes against a shared SQLite file causes write lock contention.
- **Fix:** Enable `PRAGMA journal_mode=WAL;` for single-node gateways, and migrate multi-worker task queues (`NODALIX_DB=postgres`) to **PostgreSQL 16** with `FOR UPDATE SKIP LOCKED`.

## 5. `OmniRoute storage.sqlite` Growing >1.5 GB & Startup Timeouts
- **Root Cause:** Unbounded `call_logs` accumulation slows cold starts and triggers supervisor startup timeouts.
- **Fix:** Periodically prune logs older than 14 days, run `VACUUM;`, back up exclusively using SQLite's online `.backup()` API, and set `NODE_OPTIONS=--max-old-space-size=2048`.

## 6. WebSocket Disconnection (`Code 1006`) Behind Reverse Proxy
- **Root Cause:** Reverse proxy timeouts or missing WebSocket upgrade headers break live agent chat/terminal streams.
- **Fix:** In Caddy, use `flush_interval -1`; in Nginx, set `proxy_http_version 1.1`, `Upgrade`, `Connection "upgrade"`, and `proxy_read_timeout 3600s`.

## 7. Mid-Turn Aborts in Hermes Agent (`"Execution stops randomly"`)
- **Root Cause:** Incoming signals or queued prompts interrupt active reasoning turns when `busy_input_mode` is not set to `queue`.
- **Fix:** Set `display.busy_input_mode: queue`, `gateway.signal_interrupt_grace_timeout: 10`, and `terminal.timeout: 600` in `~/.hermes/config.yaml`.

## 8. Flashing Console Windows on Windows Host Every 60 Seconds
- **Root Cause:** Windows Task Scheduler launching `powershell.exe` or `node.exe` (`CUI` subsystem) creates a visible `conhost.exe` window before `-WindowStyle Hidden` takes effect.
- **Fix:** Launch background supervisors via a tiny `Win32 GUI` subsystem wrapper (`CREATE_NO_WINDOW`, `0x08000000`) instead of raw `powershell.exe` or `wscript.exe`.

## 9. Duplicate WhatsApp Bot Replies (`WAHA + n8n`)
- **Root Cause:** `WAHA` fires both `message` and `message.any` events, or a user sends 3 rapid messages in 4 seconds.
- **Fix:** Deduplicate by `message_id` in Redis (`SET key 1 EX 300 NX`), debounce inbound bursts over a 3–5s window, and filter `fromMe == true`.
