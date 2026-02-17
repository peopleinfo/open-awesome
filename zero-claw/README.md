# Zero Claw Starter

Minimal end-user starter for:

- Electron desktop dashboard with modular sections (`Overview`, `Setup`, `Todos`, `Integrations`, `Agent`)
- Local Node API (shared Todo + settings store)
- Telegram command control (`/todo ...`) against the same data
- ZeroClaw CLI actions from GUI (status, gateway start/stop, diagnostics, prompt)

## What This Gives You

1. Setup wizard UI for app name + Telegram token + webhook URL/secret.
2. Setup wizard can apply Codex defaults to zeroclaw config from GUI (`openai` + `gpt-5.2-codex`).
3. Desktop and Telegram both read/write a shared Todo list.
4. API binds to localhost by default (`127.0.0.1:3010`).
5. Telegram webhook endpoint is available at `/api/telegram/webhook`.
6. Persistent local data:
   - `zero-claw/data/todos.json`
   - `zero-claw/data/settings.json`
   - `zero-claw/data/zeroclaw-gateway.log`

## Quick Start

### Windows

1. Open `cmd.exe` or PowerShell.
2. Run `<repo_root>\zero-claw\run.bat`.
3. The script installs dependencies (first run), starts API and then opens Electron.
4. Open `Setup Wizard` in the app and complete required checklist.

### Linux

1. Open a shell.
2. Run:
   ```bash
   cd <repo_root>/zero-claw
   chmod +x run.sh
   ./run.sh
   ```
3. Open `Setup Wizard` in the app and save your app settings.
4. Click `Complete Required Setup` after ZeroClaw + Telegram checks are satisfied.

## Telegram Flow

Use one of these methods:

1. UI method (recommended):
   - Open `Setup Wizard` in desktop.
   - Click `Install ZeroClaw` (one-click install from GUI).
   - Click `Set Codex Defaults` (or use `Complete Required Setup`, which auto-applies Codex defaults).
   - Enter bot token + webhook URL.
   - Click `Probe Telegram`, then `Set Webhook`.
   - Click `Complete Required Setup`.
2. Env method (fallback):
   - Set `TELEGRAM_BOT_TOKEN` and optional `TELEGRAM_WEBHOOK_SECRET` in `<repo_root>/zero-claw/.env`.

Then expose your local API endpoint publicly and register:

- `https://<public-host>/api/telegram/webhook`

Telegram commands:

- `/todo list`
- `/todo add Buy milk`
- `/todo done 1`
- `/todo reopen 1`
- `/todo delete 1`

## End-User API Contract

- `GET /api/settings`
- `PUT /api/settings`
- `GET /api/setup/readiness`
- `POST /api/settings/complete-setup`
- `POST /api/settings/telegram/probe`
- `POST /api/settings/telegram/set-webhook`
- `GET /api/zeroclaw/status`
- `GET /api/zeroclaw/defaults`
- `POST /api/zeroclaw/defaults/codex`
- `POST /api/zeroclaw/gateway/start`
- `POST /api/zeroclaw/gateway/stop`
- `GET /api/zeroclaw/gateway/logs?tail=300`
- `POST /api/zeroclaw/doctor`
- `POST /api/zeroclaw/channels-doctor`
- `POST /api/zeroclaw/install`
- `GET /api/zeroclaw/install/status`
- `POST /api/zeroclaw/agent/prompt`
- `GET /api/todos`
- `POST /api/todos` with JSON `{ "title": "..." }`
- `PUT /api/todos/:id` with JSON `{ "title": "...", "done": true|false }`
- `DELETE /api/todos/:id`
- `POST /api/telegram/webhook` for Telegram update payload
- `GET /health`

## Notes

- This scaffold keeps Todo as a sample module so you can expand with more modules.
- Desktop menu supports section navigation (`Overview`, `Setup`, `Todos`, `Integrations`, `Agent`).
- `Todos` and other user modules are locked until required setup is complete.
- Required setup gates: ZeroClaw installed + Telegram token + completion action.
- Telegram webhook URL is recommended but optional for unlocking modules.
- Settings + tokens remain local-only in gitignored files.
- Todo metadata tracks source (`dashboard` or `telegram`).
- ZeroClaw CLI must be installed on host for Agent module actions.
- GUI `Install ZeroClaw` runs as background job; poll status in UI output until completion.
- Codex defaults are applied via GUI as `default_provider=openai` and `default_model=gpt-5.2-codex`.
- Agent Prompt auto-falls back to Codex OAuth (`codex login`) if zeroclaw provider auth is missing/invalid, so prompts can run without `OPENAI_API_KEY`.
