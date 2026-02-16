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
- `openClaw/apply-openai-oauth.bat`: import local Codex OAuth into OpenClaw auth profiles (with bounded retry on OAuth refresh failure).
- `openClaw/config-telegram.bat`: configure Telegram bot channel in OpenClaw.
- `openClaw/pinokio-host.bat`: start/stop/status/logs helper for running Pinokio web in OpenClaw and exposing it on host `localhost:42000`.

## Quick Start (Windows)

1. Open `cmd.exe` as Administrator.
2. Run `openClaw\setup-sandbox.bat`.
3. Confirm services with `docker compose -f openClaw\docker-compose.yml ps`.
4. For normal start after setup, run `openClaw\run.bat`.
5. Open the `Dashboard with token` URL printed by `run.bat`.
6. If upgrading from an older setup, run `openClaw\setup-sandbox.bat` once to migrate compose mounts and gateway config.
7. To enable Codex OAuth auth for agent LLM, run `openClaw\apply-openai-oauth.bat`.
   If you hit `OAuth token refresh failed for openai-codex`, the script retries automatically once (default) and then prompts for `codex login` if re-auth is still required.
8. To configure Telegram channel, run `openClaw\config-telegram.bat` and enter your bot token.
9. To run Pinokio web and open it from host, run `openClaw\pinokio-host.bat start`, then browse `http://localhost:42000`.
   If first launch is still warming up, run `openClaw\pinokio-host.bat status` until it reports healthy.

Or run interactive menu (Git Bash/WSL shell):

1. Run `bash menu.sh`.
2. Pick install actions from the menu.

## Notes

- The setup script creates `openClaw/.env` with generated secrets if missing.
- The setup script creates `openClaw/config/openclaw.json` if missing to allow local Control UI token auth.
- `apply-openai-oauth.bat` supports `--max-retries N` and `--skip-probe` for OAuth bootstrap control.
- `pinokio-host.bat` supports `start`, `stop`, `status`, and `logs`.
- Pinokio first launch may take 30-90 seconds and can restart once while initializing/migrating home data.
- Pinokio runtime home defaults to Docker volume `pinokio_data` mounted at `/pinokio-data` to avoid Windows bind-mount stalls during conda setup.
- Telegram bot tokens are stored only in `openClaw/config/openclaw.json` (gitignored).
- `config-telegram.bat` sets `channels.telegram.allowFrom=["*"]` and `channels.telegram.dmPolicy=allowlist` for local DM testing.
- The default image is `ghcr.io/openclaw/openclaw:latest` (official registry path).
- Docker bind model: `OPENCLAW_HOST_BIND=127.0.0.1` (host exposure), `OPENCLAW_GATEWAY_BIND=lan` (OpenClaw bind mode inside container).
- Additional localhost port forward is enabled for host access to services listening on container `42000` (`127.0.0.1:42000 -> 42000`).
- Docker volumes: `openClaw/config -> /home/node/.openclaw` and `openClaw/workspace -> /home/node/.openclaw/workspace`.
- Docker Desktop must already be installed and running.
- The gateway defaults to `127.0.0.1:18789`.
- For live logs, use `docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env logs -f openclaw`.
