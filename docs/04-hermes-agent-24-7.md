# Step 04 — Hermes Agent 24/7, Guardrails & Multi-Worker DAG

[**Hermes Agent**](https://github.com/NousResearch/hermes-agent) serves as the **24/7 autonomous orchestrator**: managing persistent memory, scheduled routines, Telegram/Slack gateways, browser tools, and delegating heavy coding jobs to Claude Code CLI.

---

## 1. Installation

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
hermes --version
```

---

## 2. Clean Separation: `~/.hermes/.env` vs `~/.hermes/config.yaml`

Follow Hermes Agent's strict separation of secrets and runtime configuration:
- **`~/.hermes/.env`**: Exclusively stores API keys, OmniRoute token, Telegram Bot Token, and `TELEGRAM_GROUP_ALLOWED_USERS`.
- **`~/.hermes/config.yaml`**: Stores model selection, fallback providers, terminal limits, loop guardrails, MCP servers, and gateway watchdog settings.

### Critical Production Guardrails in `config.yaml`

Without these guardrails (included in [`configs/hermes-config.example.yaml`](../configs/hermes-config.example.yaml)), long-running 24/7 agents suffer mid-turn aborts, context overflow, or infinite tool loops:

```yaml
model:
  default: claude-sonnet-4-6
  provider: openai-compatible
  base_url: http://127.0.0.1:20128/v1

fallback_providers:
  - provider: openai-compatible
    model: gemini-3.8-flash-high
  - provider: openai-compatible
    model: auto-omni-resilient

display:
  # CRITICAL: Prevents mid-turn abort if a signal/message arrives while thinking
  busy_input_mode: queue

terminal:
  backend: local
  timeout: 600 # Allows builds, Docker pulls, and test suites to finish

tool_loop_guardrails:
  warnings_enabled: true
  hard_stop_enabled: true
  warn_after:
    exact_failure: 2
    same_tool_failure: 3
    idempotent_no_progress: 2
  hard_stop_after:
    exact_failure: 5
    same_tool_failure: 8
    idempotent_no_progress: 5

compression:
  enabled: true
  threshold: 0.5
  target_ratio: 0.2
  protect_last_n: 20

gateway:
  signal_interrupt_grace_timeout: 10
  delivery_ledger: true
  loop_watchdog: true
  loop_watchdog_probe_interval_s: 30.0
```

> [!TIP]
> **Disable unused desktop MCP servers:** If an optional MCP server (such as a video editor plugin) is not running on the host, set `enabled: false` in `config.yaml` to eliminate 15–20 second startup connection retry lags on every turn.

---

## 3. Identity, Memory & OAuth Governance (`SOUL.md` & `AGENTS.md`)

- **`~/.hermes/SOUL.md`**: Defines role identity, concise reporting format, and strict approval gates (never send unsolicited mass emails, never execute unverified payments, never expose secrets).
- **`~/.hermes/AGENTS.md`**: Encodes operational rules—including which single authorized agency OAuth profile to pick during browser logins, concurrency caps (`max 2–3 concurrent subagents` on 4 GB VPS), and the delegation threshold for handing coding builds off to Claude Code.

---

## 4. Avoiding Context Overflow & Drift in 24/7 Multi-Agent Workflows

Leaving 10–20 perpetual chat sessions open causes rapid token explosion and context drift. Instead, structure 24/7 automation as a **finite-job DAG**:

1. **Stateless One-Shot Workers:** Scheduled jobs invoke fresh bounded turns (`hermes chat --oneshot --query-file job_payload.json`) capped at `<28 KB` payload and `<6,500` chars of episodic memory retrieval.
2. **PostgreSQL 16 Queue (Not SQLite) Under Concurrency:** When running multiple concurrent workers, SQLite throws `database is locked`. Use PostgreSQL 16 with row-level locking (`SELECT ... FOR UPDATE SKIP LOCKED`), `dedupe_key`, `lease_until`, and `max_retries = 3` before routing to a `dead` or `needs_review` queue.
3. **Human Review Gate (`needs_review`):** Complex client deliverables transition to `needs_review` until an operator verifies test output and approves release.

---

## 5. Async Delegation: Hermes → Claude Code

Use [`scripts/delegate_to_claude_code.example.py`](../scripts/delegate_to_claude_code.example.py) so Hermes can spawn isolated Claude Code execution runs per client directory, capture structured JSON output, and log every handoff to `client_project_handoffs.jsonl`.

---

## Next Step
Proceed to **[05 — Playwright MCP & Brave/Chrome CDP Automation](05-browser-automation-playwright-brave.md)**.
