# Step 05 — Playwright MCP & Brave/Chrome CDP Browser Automation

Both **Hermes Agent** and **Claude Code** rely on browser automation for live dashboard configuration, authenticated SaaS integration, visual UI verification, and E2E testing. Running Chromium browsers reliably 24/7 requires strict memory hygiene on Linux VPS and desktop-station binding on Windows.

---

## 1. Connecting Playwright MCP (`@playwright/mcp`)

Install the Playwright MCP server globally:
```bash
npm install -g @playwright/mcp
```

### Option A: Connect to an Existing Browser via CDP Endpoint (Recommended for Persistent Auth)
Launch Brave or Chrome with `--remote-debugging-port=9224` (bound strictly to `127.0.0.1`), then attach Playwright MCP via `--cdp-endpoint`:

```json
{
  "mcpServers": {
    "playwright-cdp": {
      "command": "npx",
      "args": [
        "-y",
        "@playwright/mcp@latest",
        "--cdp-endpoint",
        "http://127.0.0.1:9224"
      ]
    }
  }
}
```

### Option B: Connect via Playwright MCP Extension Token
When operating an already-open profile through the official browser extension:
```json
{
  "mcpServers": {
    "playwright-extension": {
      "command": "npx",
      "args": [
        "-y",
        "@playwright/mcp@latest",
        "--extension",
        "--browser",
        "chrome"
      ],
      "env": {
        "PLAYWRIGHT_MCP_EXTENSION_TOKEN": "YOUR_PLAYWRIGHT_EXTENSION_TOKEN"
      }
    }
  }
}
```
> [!WARNING]
> Treat `PLAYWRIGHT_MCP_EXTENSION_TOKEN` as a secret. Never commit real tokens or paste them into public logs.

---

## 2. Single-Window & Tab-Group RAM Hygiene (VPS Protection)

Each Chromium renderer tab consumes **150–250 MiB of RAM**. On a 3.7–4 GiB Linux VPS, opening unmanaged tabs quickly causes OOM crashes. Enforce these rules in `AGENTS.md`:

1. **Single Window Mandate:** Never spawn multiple browser windows. Operate all tasks inside one dedicated window on `DISPLAY=:10` with memory-saving flags:
   ```bash
   brave-browser \
     --remote-debugging-port=9224 \
     --renderer-process-limit=2 \
     --disable-dev-shm-usage \
     --js-flags="--max-old-space-size=256"
   ```
2. **Tab Deduplication:** Before navigating to a URL, list open tabs (`browser_tabs` -> `list`). If the target domain is already open, select that existing tab instead of loading a duplicate renderer.
3. **Aggressive Tab Closure:** Keep a strict ceiling of `1–2` active tabs; immediately close temporary OAuth or lookup tabs upon completion.
4. **Native OS Cursor Preservation:** Do not inject fake DOM cursors or `cursor: none !important` styles—preserve the standard OS cursor so screenshots and user interaction remain clean.

---

## 3. Windows Local Workstations: Solving Invisible Windows & Job Object Kills

When running autonomous agents from background shells on Windows 11:
- **Desktop Station Isolation:** Subshells often execute inside a hidden virtual desktop (`exebox-...`), making launched GUI browsers invisible on the physical monitor.
- **Job Object Termination:** Windows kills child processes when the short-lived command returns.

**Solution ([`scripts/launch_browser_win.example.ps1`](../scripts/launch_browser_win.example.ps1)):**
1. Purge orphaned zero-HWND processes holding the Chromium `SingletonLock`.
2. Invoke the browser binary via Win32 `CreateProcess` with `STARTUPINFO.lpDesktop = @"WinSta0\Default"`.
3. Keep the launcher script running under a silent daemon loop (`while ($true) { Start-Sleep -Seconds 10 }`).
4. Never launch `powershell.exe`, `cmd.exe`, or `node.exe` visibly on `WinSta0\Default`—use headless wrappers (`CREATE_NO_WINDOW`) for background scripts so zero console popups steal focus.

---

## Next Step
Proceed to **[06 — 24/7 Watchdog, Task Bridge & Docker Stack](06-watchdog-monitoring-and-omnichannel.md)**.
