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

## Optional Channel Task

- `openClaw/config-telegram.bat`

Expected outcomes:

1. Accept Telegram bot token via prompt/arg/env.
2. Configure Telegram channel on running OpenClaw container.
3. Set local DM access defaults (`allowFrom=["*"]`, `dmPolicy=allowlist`) to avoid unauthorized command responses.
4. Keep token only in gitignored local config.

## Definition Of Done

- A new machine can run the first task with minimal manual steps.
- No hard-coded public bind address.
- Secrets are not committed to git.
