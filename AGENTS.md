# AGENTS

## Mission

Build and maintain this repository as a practical launcher for developer tooling:

- project setup automation
- AI/agent/LLM local workflows
- secure sandbox-first execution

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
7. Keep localhost-only forwards for gateway and local workspace/API service ports (`18789`, `42000`, `30001->30001`).
8. Keep `openClaw/run.bat` usable in unattended startup mode (`auto`) with no interactive prompt requirement.
9. Keep `openClaw/run.bat` no-arg default aligned with unattended startup (`auto --wait-pinokio 240`) and keep `--manual` as explicit opt-out.

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
