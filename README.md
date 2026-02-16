# Open Awesome

Bootstrap workspace for building and operating programming, AI, agent, and LLM tooling with a secure local sandbox.

## Current Scope

- Establish project docs and agent operating conventions.
- Provide a first runnable task: OpenClaw Docker sandbox setup on Windows.
- Keep setup idempotent and safe by default.

## Repository Layout

- `README.md`: project overview and startup flow.
- `AGENTS.md`: rules for AI agents working in this repo.
- `SKILL.md`: reusable skill instructions for this project.
- `menu.sh`: interactive menu to pick install/setup actions.
- `skill.sh`: helper to initialize/validate skill metadata files.
- `openClaw/setup-sandbox.bat`: Windows setup entrypoint for local sandboxing.
- `openClaw/run.bat`: Windows quick start for launching OpenClaw.
- `openClaw/apply-openai-oauth.bat`: import local Codex OAuth into OpenClaw auth profiles.

## Quick Start (Windows)

1. Open `cmd.exe` as Administrator.
2. Run `openClaw\setup-sandbox.bat`.
3. Confirm services with `docker compose -f openClaw\docker-compose.yml ps`.
4. For normal start after setup, run `openClaw\run.bat`.
5. If Control UI shows `1008 unauthorized`, open the `Dashboard with token` URL printed by `run.bat`.
6. To enable Codex OAuth auth for agent LLM, run `openClaw\apply-openai-oauth.bat`.

Or run interactive menu (Git Bash/WSL shell):

1. Run `bash menu.sh`.
2. Pick install actions from the menu.

## Notes

- The setup script creates `openClaw/.env` with generated secrets if missing.
- The default image is `ghcr.io/openclaw/openclaw:latest` (official registry path).
- Docker bind model: `OPENCLAW_HOST_BIND=127.0.0.1` (host exposure), `OPENCLAW_GATEWAY_BIND=lan` (OpenClaw bind mode inside container).
- Docker Desktop must already be installed and running.
- The gateway defaults to `127.0.0.1:18789`.
