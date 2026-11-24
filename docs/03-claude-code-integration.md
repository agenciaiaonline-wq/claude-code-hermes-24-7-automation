# Step 03 — Claude Code CLI & Project Executor Integration

In this setup, **Claude Code CLI** acts as the **heavy engineering executor**: scaffolding SaaS MVPs, refactoring TypeScript/Python backends, running Playwright & unit tests, and generating programmatic videos/assets via Remotion & HyperFrames.

---

## 1. Install Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
claude --version
```

---

## 2. Wire Claude Code to OmniRoute (`~/.claude/settings.json`)

Claude Code natively supports routing all API calls to a custom gateway via `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` inside `~/.claude/settings.json` (see [`configs/claude-settings.example.json`](../configs/claude-settings.example.json)):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:20128/v1",
    "ANTHROPIC_AUTH_TOKEN": "sk-example-replace-with-your-local-omniroute-key",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-6-thinking",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4-6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "gemini-3.8-flash-high"
  },
  "model": "claude-sonnet-4-6"
}
```

> [!NOTE]
> Make sure your OmniRoute API key has `model_access_mode = 'all'` (or explicitly permits `combo/*` and your desired provider prefixes) so dynamic `/model` switching inside Claude Code never fails with `HTTP 400`.

### Create Quick Model Launchers (`~/.local/bin/`)
Add convenient aliases to `~/.bashrc`:
```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:20128/v1"
export ANTHROPIC_AUTH_TOKEN="sk-example-replace-with-your-local-omniroute-key"

alias claude-opus='claude --model claude-opus-4-6-thinking'
alias claude-sonnet='claude --model claude-sonnet-4-6'
alias claude-flash='claude --model gemini-3.8-flash-high'
alias claude-combo='claude --model auto-coding-elite'
```

---

## 3. Headless Automation Mode (`claude -p`)

When **Hermes Agent** or a CI/CD cron job delegates work to Claude Code, there is no human at the keyboard. Use Claude Code's `-p` (`--print`) non-interactive mode:

```bash
# Scoped headless execution with explicit tool allowlist & structured JSON output
claude -p "Implement Stripe webhook signature verification and run pytest" \
  --allowedTools "Read,Edit,Bash,Glob,Grep" \
  --output-format json
```

### Important Headless Flags
- `-p` / `--print`: Skips the interactive TUI, executes, prints output, and returns standard Unix exit codes (`0` on success).
- `--allowedTools`: Restricts autonomous runs to approved tools (`Read,Edit,Bash`).
- `--output-format json` or `stream-json`: Enables deterministic parsing of results, session IDs, and token cost by `delegate_to_claude_code.py`.
- `--bare`: Useful in strict CI pipelines to avoid loading unrelated user hooks.

---

## 4. The Project Executor Contract (`CLAUDE.md`)

Place [`configs/CLAUDE.example.md`](../configs/CLAUDE.example.md) at the root of your client workspace (`/home/ubuntu/client_projects/CLAUDE.md`) so every Claude Code invocation respects strict boundaries:

1. **Infrastructure Isolation:** Claude Code must NEVER alter running core services (OmniRoute, WAHA, n8n, Postgres) while building a client repository.
2. **Per-Client Workspace:** Each project lives in `/home/ubuntu/client_projects/<project-slug>/` with its own Git repo and `.env.example`.
3. **Display Binding:** Any visual test or video render uses `DISPLAY=:99` (Xvfb) to avoid hijacking interactive desktop windows.
4. **Completion Handoff:** Every delegated run writes a structured JSONL entry (`client_project_handoffs.jsonl`) and triggers a completion notification back to Hermes Agent.

---

## 5. Creative & DevOps Tooling Attached to Claude Code

For high-ticket agency deliverables, equip the executor environment with:
- **GitHub MCP** — automated branch, PR, and release workflows.
- **Remotion v4 + FFmpeg + ImageMagick** — programmatic product launch reels, SaaS walkthrough videos, and dynamic thumbnails.
- **Playwright CLI** — automated end-to-end verification and screenshot validation before delivering to clients.

---

## Next Step
Proceed to **[04 — Hermes Agent 24/7 & Multi-Worker DAG](04-hermes-agent-24-7.md)**.
