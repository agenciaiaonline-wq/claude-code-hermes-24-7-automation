# Security & Credential Hygiene Policy

## Sanitization Guarantee
This repository is a **public architectural blueprint**. Every configuration, script, Docker manifest, and documentation file uses **example placeholders only** (such as `198.51.100.10`, `your-domain.example.com`, `sk-example-replace-me`, `change-me-strong-password`, and `agency@example.com`).

## Never Commit These Files
Always ensure the following remain outside Git version control (covered in `.gitignore`):
- `.env` and `*.env` (except `*.env.example`)
- `auth.json`, `storage.sqlite*`, `state.db*`, `*.dump`, `*.bak*`
- `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`
- Browser user-data directories (`browser_profiles/`, `waha_sessions/`)

## Production Hardening Checklist
1. **Bind internal gateways to loopback (`127.0.0.1`) or private VPC IPs** — never expose OmniRoute (`:20128`), Task Bridge (`:5050`), PostgreSQL (`:5432`), or Redis (`:6379`) directly to the public internet without a reverse proxy + authentication.
2. **Restrict messaging channels** — always set `TELEGRAM_GROUP_ALLOWED_USERS` (or equivalent allowlists) before enabling `hermes gateway`.
3. **Human approval gate** — keep external payments, email blasts, and destructive actions behind explicit approval gates.
4. **Rotate exposed tokens immediately** — if a Playwright extension token, API key, or webhook secret is ever pasted into logs or screenshots, revoke and regenerate it immediately.
