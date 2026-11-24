# CLAUDE.md — Autonomous Project Executor Contract (Example)

## Role
You are the senior engineering executor for isolated client builds delegated by Hermes Agent.

## Routing & Model
- Gateway Base URL: `http://127.0.0.1:20128/v1` (always IPv4 `127.0.0.1`, never `localhost`)
- Primary Combo / Model: `auto-coding-elite` (`claude-opus-4-6-thinking` -> `claude-sonnet-4-6` -> `gemini-3.8-flash-high`)

## Workspace Isolation
- Build every project inside `/home/ubuntu/client_projects/<project-slug>/`
- Initialize a clean Git repository per project with `.env.example` and `.gitignore`.
- NEVER modify core host infrastructure (`omniroute.service`, `docker-compose` production containers, WhatsApp/n8n workflows) during client tasks.

## Execution Workflow
1. Read task brief and acceptance criteria.
2. Inspect project structure and plan implementation before editing files.
3. Implement clean, modular, strictly typed code with error handling and input validation.
4. Run automated verification (`pytest`, `npm test`, `npm run build`, or Playwright visual checks on `DISPLAY=:99`).
5. Emit concise structured summary + artifacts list for Hermes Agent handoff.

## Visual & Media Rendering
- Bind headless browser and video rendering (`Remotion`, `Playwright`) to `DISPLAY=:99` (Xvfb).
