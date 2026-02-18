# AGENTS

## Mission

Build and maintain this repository as a practical launcher for developer tooling:

- project setup automation
- AI/agent/LLM local workflows
- secure sandbox-first execution
- end-user dashboard starter flows (Electron + local API + channel control)

## Working Rules

1. Keep setup scripts idempotent. Running twice must not break state.
2. Default to local-only network binding unless explicitly requested otherwise.
3. Favor secure defaults over convenience.
4. Update `README.md`, `AGENTS.md`, and `SKILL.md` together when workflow changes.
5. Prefer small, reviewable commits with clear file-level intent.
6. When documenting output/workspace navigation, include Windows and Linux examples using `<repo_root>` placeholders (no hard-coded usernames).

## First Task

Primary bootstrap entrypoint:

- `openClaw/setup-sandbox.bat`

Expected outcomes:

1. Verify Docker and Docker Compose are available.
2. Create required local directories.
3. Generate a secure `.env` file when missing.
4. Generate `openClaw/config/openclaw.json` when missing for local Control UI auth.
5. Create `openClaw/docker-compose.yml` when missing (and migrate legacy volume mounts when detected).
6. Pull and start OpenClaw in detached mode.
7. Keep localhost-only forwards for gateway and local workspace/API service ports (`18789`, `42000`, `30001->30001`, `30110->30110`).
8. Keep `openClaw/run.bat` usable in unattended startup mode (`auto`) with no interactive prompt requirement.
9. Keep `openClaw/run.bat` no-arg default aligned with unattended startup (`auto --wait-pinokio 240`) and keep `--manual` as explicit opt-out.
10. Ensure sandbox Git commits work from agent/Telegram flows by providing a persistent local Git identity config.

## Optional Channel Task

- `openClaw/config-telegram.bat`

Expected outcomes:

1. Accept Telegram bot token via prompt/arg/env.
2. Configure Telegram channel on running OpenClaw container.
3. Set local DM access defaults (`allowFrom=["*"]`, `dmPolicy=allowlist`) to avoid unauthorized command responses.
4. Keep token only in gitignored local config.

## Optional Pinokio Host Task

- `openClaw/pinokio-host.bat`

Expected outcomes:

1. Start Pinokio web inside the running OpenClaw container.
2. Verify host forward for `42000` exists and fail with clear remediation when missing.
3. Provide `start|stop|status|logs` controls for local operations.
4. Keep host exposure local-only via `127.0.0.1:42000`.
5. Normalize Pinokio home config for Linux container runtime before startup.
6. Keep Pinokio home on Docker-managed storage (not Windows bind mount) for stable conda/bootstrap performance.
7. Support unattended execution flags for startup automation (`--wait-ready`, `--no-pause`).

## Optional Camoufox Browser Task

- `skills/camoufox-mgt-enforcer/`

Expected outcomes:

1. Keep Camoufox manager app source at:
   - Windows: `<repo_root>\openClaw\workspace\pinokio-data\api\camoufox-mgt`
   - Linux: `<repo_root>/openClaw/workspace/pinokio-data/api/camoufox-mgt`
2. Keep host exposure local-only for Camoufox manager API via `127.0.0.1:30110`.
3. Keep container app bind set for Docker publish (`HOST=0.0.0.0`, `PORT=30110`).
4. Enforce Camoufox browser usage for browser automation unless user explicitly opts out.
5. Require health validation at `http://localhost:30110/health` before browser automation steps.

## Optional End-User Dashboard Task

- `zero-claw/`

Expected outcomes:

1. Provide a runnable Electron dashboard starter for non-technical users.
2. Keep API binding local-only by default (`127.0.0.1`).
3. Support Todo CRUD from desktop UI and Telegram webhook commands over the same data store.
4. Keep local Todo data and channel secrets gitignored (`zero-claw/.env`, `zero-claw/data/todos.json`).
5. Provide Windows and Linux startup entrypoints (`run.bat`, `run.sh`) with minimal setup steps.
6. Keep a first-run setup wizard in the desktop UI for app name + Telegram webhook/token onboarding.
7. Keep local setup state gitignored (`zero-claw/data/settings.json`).
8. Provide a GUI-first Agent module for common `zeroclaw` operations (status, gateway start/stop, diagnostics, prompt).
9. Keep end-user modules locked until required setup is completed (`Complete Required Setup` flow).
10. Treat Telegram webhook URL as recommended/optional unless explicitly requested as a hard requirement.
11. Provide GUI-driven ZeroClaw installation action so end users can bootstrap CLI without terminal commands.
12. Default ZeroClaw agent profile to Codex-friendly settings from GUI (`default_provider=openai`, `default_model=gpt-5.2-codex`) with no terminal requirement.
13. For Agent Prompt, support OAuth-first fallback via local Codex session (`codex login`) when zeroclaw provider credentials are unavailable.

## OAuth Recovery Task

- `openClaw/apply-openai-oauth.bat`

Expected outcomes:

1. Import host Codex OAuth tokens into OpenClaw auth profiles.
2. Set `openai-codex/gpt-5.3-codex` as the main agent model.
3. Detect `OAuth token refresh failed for openai-codex` / `refresh_token_reused` and retry import with bounded attempts.
4. If retries are exhausted, provide explicit re-auth steps (`codex login`) and log command guidance.
5. Support explicit account switching via re-auth mode before import (for example `--re-auth`).

## Definition Of Done

- A new machine can run the first task with minimal manual steps.
- No hard-coded public bind address.
- Secrets are not committed to git.
