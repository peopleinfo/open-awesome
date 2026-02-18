# Open Awesome

Bootstrap workspace for building and operating programming, AI, agent, and LLM tooling with a secure local sandbox.

## Current Scope

- Establish project docs and agent operating conventions.
- Provide a first runnable task: OpenClaw Docker sandbox setup on Windows.
- Provide a second runnable task: Zero Claw end-user dashboard starter (Electron + Telegram CRUD).
- Keep setup idempotent and safe by default.

## Repository Layout

- `README.md`: project overview and startup flow.
- `AGENTS.md`: rules for AI agents working in this repo.
- `SKILL.md`: reusable skill instructions for this project.
- `skills/camoufox-mgt-enforcer/SKILL.md`: enforce Camoufox browser usage with the local camoufox profile manager app on `localhost:30110`.
- `menu.sh`: interactive menu to pick install/setup actions.
- `skill.sh`: helper to initialize/validate skill metadata files.
- `openClaw/setup-sandbox.bat`: Windows setup entrypoint for local sandboxing.
- `openClaw/run.bat`: Windows quick start for launching OpenClaw.
- `openClaw/apply-openai-oauth.bat`: import local Codex OAuth into OpenClaw auth profiles (with bounded retry on OAuth refresh failure).
- `openClaw/config-telegram.bat`: configure Telegram bot channel in OpenClaw.
- `openClaw/pinokio-host.bat`: start/stop/status/logs helper for running Pinokio web in OpenClaw and exposing it on host `localhost:42000`.
- `zero-claw/`: end-user starter workspace for Electron dashboard + local Todo API + Telegram webhook CRUD flow.

## Quick Start (Windows)

1. Open `cmd.exe` as Administrator.
2. Run `openClaw\setup-sandbox.bat`.
3. Confirm services with `docker compose -f openClaw\docker-compose.yml ps`.
4. For normal start after setup, run `openClaw\run.bat`.
   Default behavior is unattended startup with no Pinokio readiness wait (`auto`).
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

## Zero Claw Starter (End User Flow)

1. Windows: run `<repo_root>\zero-claw\run.bat`.
2. Linux: run `<repo_root>/zero-claw/run.sh`.
3. This starts:
   - local API on `127.0.0.1:3010`
   - Electron dashboard with sections (`Overview`, `Setup`, `Todos`, `Integrations`, `Agent`)
4. In desktop `Setup Wizard`, set app name + Telegram token + webhook URL.
5. Click `Set Codex Defaults` (or use `Complete Required Setup`, which applies Codex defaults automatically) so ZeroClaw uses OpenAI Codex profile by default.
6. Click `Complete Required Setup` to unlock user modules.
7. To enable Telegram CRUD without UI, set token in `<repo_root>/zero-claw/.env`:
   - `TELEGRAM_BOT_TOKEN=...`
8. Register your Telegram webhook to:
   - `https://<public-host>/api/telegram/webhook`
9. Telegram and Electron both manage the same Todo store (`zero-claw/data/todos.json`).

## Notes

- The setup script creates `openClaw/.env` with generated secrets if missing.
- The setup script creates `openClaw/config/openclaw.json` if missing to allow local Control UI token auth.
- `apply-openai-oauth.bat` supports `--max-retries N`, `--skip-probe`, and `--re-auth` for OAuth bootstrap/account switching.
- `pinokio-host.bat` supports `start`, `stop`, `status`, and `logs`.
- `pinokio-host.bat` also supports `--wait-ready SECONDS` and `--no-pause` for unattended startup.
- `run.bat` supports `auto`, `--manual`, `--start-pinokio`, `--wait-pinokio SECONDS`, and `--no-pause`.
- `run.bat` no-arg default is equivalent to unattended startup with no Pinokio readiness wait (`auto`).
- Sandbox Git identity defaults are stored in `openClaw/config/gitconfig` and mounted as global Git config in the container so Telegram/agent `git commit` works unattended.
- Pinokio first launch may take 30-90 seconds and can restart once while initializing/migrating home data.
- Pinokio runtime home defaults to Docker volume `pinokio_data` mounted at `/pinokio-data` to avoid Windows bind-mount stalls during conda setup.
- Telegram bot tokens are stored only in `openClaw/config/openclaw.json` (gitignored).
- `config-telegram.bat` sets `channels.telegram.allowFrom=["*"]` and `channels.telegram.dmPolicy=allowlist` for local DM testing.
- The default image is `ghcr.io/openclaw/openclaw:latest` (official registry path).
- Docker bind model: `OPENCLAW_HOST_BIND=127.0.0.1` (host exposure), `OPENCLAW_GATEWAY_BIND=lan` (OpenClaw bind mode inside container).
- Additional localhost forwards are enabled for host access to container-local services:
  `127.0.0.1:42000 -> 42000` (Pinokio web), `127.0.0.1:30001 -> 30001` (API docs, for example `http://localhost:30001/api/docs`), and
  `127.0.0.1:30110 -> 30110` (camoufox profile manager API, for example `http://localhost:30110/health`).
  Host forwards are published at container start, but HTTP responses depend on internal services binding to those ports.
- Docker volumes: `openClaw/config -> /home/node/.openclaw` and `openClaw/workspace -> /home/node/.openclaw/workspace`.
- Docker Desktop must already be installed and running.
- The gateway defaults to `127.0.0.1:18789`.
- For live logs, use `docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env logs -f openclaw`.
- `zero-claw` defaults to localhost API bind (`127.0.0.1:3010`) and keeps Todo data local (`zero-claw/data/todos.json`).
- `zero-claw` setup preferences are local and gitignored in `zero-claw/data/settings.json`.
- `zero-claw` Agent module can control local `zeroclaw` CLI (gateway/doctor/prompt) and writes runtime logs to `zero-claw/data/zeroclaw-gateway.log`.
- `zero-claw` setup lock requires ZeroClaw detection + Telegram token; webhook URL is optional/recommended.
- `zero-claw` Setup Wizard includes `Install ZeroClaw` to run CLI install directly from GUI.
- `zero-claw` Setup Wizard includes `Set Codex Defaults` and auto-applies Codex defaults on setup completion (`openai` + `gpt-5.2-codex`).
- `zero-claw` Agent Prompt falls back to Codex OAuth (`codex login`) when zeroclaw provider auth fails, so `OPENAI_API_KEY` is not required for prompt use.

## Host Paths (Windows + Linux)

Use `<repo_root>` as the folder where this repository is cloned (dynamic per machine/user).

- Windows workspace/output: `<repo_root>\openClaw\workspace`
- Windows config + logs: `<repo_root>\openClaw\config`
- Windows camoufox manager app: `<repo_root>\openClaw\workspace\pinokio-data\api\camoufox-mgt`
- Linux workspace/output: `<repo_root>/openClaw/workspace`
- Linux config + logs: `<repo_root>/openClaw/config`
- Linux camoufox manager app: `<repo_root>/openClaw/workspace/pinokio-data/api/camoufox-mgt`
- Windows Zero Claw workspace: `<repo_root>\zero-claw`
- Windows Zero Claw todo data: `<repo_root>\zero-claw\data\todos.json`
- Windows Zero Claw settings data: `<repo_root>\zero-claw\data\settings.json`
- Windows Zero Claw gateway log: `<repo_root>\zero-claw\data\zeroclaw-gateway.log`
- Linux Zero Claw workspace: `<repo_root>/zero-claw`
- Linux Zero Claw todo data: `<repo_root>/zero-claw/data/todos.json`
- Linux Zero Claw settings data: `<repo_root>/zero-claw/data/settings.json`
- Linux Zero Claw gateway log: `<repo_root>/zero-claw/data/zeroclaw-gateway.log`

Container path for Pinokio runtime data is fixed and user-independent:

- `pinokio_data:/pinokio-data`

## Windows Startup Automation

Use Windows Task Scheduler to run OpenClaw and Pinokio at login/startup with no prompt windows:

- Program/script: `<repo_root>\openClaw\run.bat`
- Arguments: optional, default no-arg already runs `auto` (no Pinokio readiness wait)
- Start in: `<repo_root>\openClaw`
