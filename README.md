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

## Quick Start (Windows)

1. Open `cmd.exe` as Administrator.
2. Run `openClaw\setup-sandbox.bat`.
3. Confirm services with `docker compose -f openClaw\docker-compose.yml ps`.

Or run interactive menu (Git Bash/WSL shell):

1. Run `bash menu.sh`.
2. Pick install actions from the menu.

## Notes

- The setup script creates `openClaw/.env` with generated secrets if missing.
- Docker Desktop must already be installed and running.
- The gateway defaults to `127.0.0.1:18789`.
