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
   Default behavior is unattended startup with Pinokio readiness wait (`auto --wait-pinokio 240`).
   For manual/interactive mode, run `openClaw\run.bat --manual`.
5. Open the `Dashboard with token` URL printed by `run.bat`.
6. If upgrading from an older setup, run `openClaw\setup-sandbox.bat` once to migrate compose mounts and gateway config.
7. To enable Codex OAuth auth for agent LLM, run `openClaw\apply-openai-oauth.bat`.
   If you hit `OAuth token refresh failed for openai-codex`, the script retries automatically once (default) and then prompts for `codex login` if re-auth is still required.
   To switch to a different Codex account, run `openClaw\apply-openai-oauth.bat --re-auth` and complete host login.
8. To configure Telegram channel, run `openClaw\config-telegram.bat` and enter your bot token.
9. To run Pinokio web and open it from host, run `openClaw\pinokio-host.bat start`, then browse `http://localhost:42000`.
   If first launch is still warming up, run `openClaw\pinokio-host.bat status` until it reports healthy.

Or run interactive menu (Git Bash/WSL shell):

1. Run `bash menu.sh`.
2. Pick install actions from the menu.

## Notes

- The setup script creates `openClaw/.env` with generated secrets if missing.
- The setup script creates `openClaw/config/openclaw.json` if missing to allow local Control UI token auth.
- `apply-openai-oauth.bat` supports `--max-retries N`, `--skip-probe`, and `--re-auth` for OAuth bootstrap/account switching.
- `pinokio-host.bat` supports `start`, `stop`, `status`, and `logs`.
- `pinokio-host.bat` also supports `--wait-ready SECONDS` and `--no-pause` for unattended startup.
- `run.bat` supports `auto`, `--manual`, `--start-pinokio`, `--wait-pinokio SECONDS`, and `--no-pause`.
- `run.bat` no-arg default is equivalent to unattended startup with Pinokio wait (`auto --wait-pinokio 240`).
- Pinokio first launch may take 30-90 seconds and can restart once while initializing/migrating home data.
- Pinokio runtime home defaults to Docker volume `pinokio_data` mounted at `/pinokio-data` to avoid Windows bind-mount stalls during conda setup.
- Telegram bot tokens are stored only in `openClaw/config/openclaw.json` (gitignored).
- `config-telegram.bat` sets `channels.telegram.allowFrom=["*"]` and `channels.telegram.dmPolicy=allowlist` for local DM testing.
- The default image is `ghcr.io/openclaw/openclaw:latest` (official registry path).
- Docker bind model: `OPENCLAW_HOST_BIND=127.0.0.1` (host exposure), `OPENCLAW_GATEWAY_BIND=lan` (OpenClaw bind mode inside container).
- Additional localhost forwards are enabled for host access to container-local services:
  `127.0.0.1:42000 -> 42000` (Pinokio web) and `127.0.0.1:30001 -> 30001` (API docs, for example `http://localhost:30001/api/docs`).
  The `30001` forward is published at container start, but HTTP responses depend on an internal service binding to `30001`.
- Docker volumes: `openClaw/config -> /home/node/.openclaw` and `openClaw/workspace -> /home/node/.openclaw/workspace`.
- Docker Desktop must already be installed and running.
- The gateway defaults to `127.0.0.1:18789`.
- For live logs, use `docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env logs -f openclaw`.

## Host Paths (Windows + Linux)

Use `<repo_root>` as the folder where this repository is cloned (dynamic per machine/user).

- Windows workspace/output: `<repo_root>\openClaw\workspace`
- Windows config + logs: `<repo_root>\openClaw\config`
- Linux workspace/output: `<repo_root>/openClaw/workspace`
- Linux config + logs: `<repo_root>/openClaw/config`

Container path for Pinokio runtime data is fixed and user-independent:

- `pinokio_data:/pinokio-data`

## Windows Startup Automation

Use Windows Task Scheduler to run OpenClaw and Pinokio at login/startup with no prompt windows:

- Program/script: `<repo_root>\openClaw\run.bat`
- Arguments: optional, default no-arg already runs `auto --wait-pinokio 240`
- Start in: `<repo_root>\openClaw`
