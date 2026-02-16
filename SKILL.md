---
name: open-awesome-bootstrap
description: Bootstrap and maintain this repository for programming, AI, agent, and LLM tooling with secure local setup automation. Use when creating or updating core project scaffolding, setup scripts, and agent workflow docs (README.md, AGENTS.md, SKILL.md, and OpenClaw setup files).
---

# Open Awesome Bootstrap Workflow

## Keep Core Files In Sync

1. Update `README.md` when startup commands or structure changes.
2. Update `AGENTS.md` when execution rules or safety expectations change.
3. Keep this file focused on reusable, procedural guidance.

## Setup Script Standards

1. Make scripts safe-by-default and idempotent.
2. Bind services to localhost unless explicitly required otherwise.
3. Generate secrets at runtime when missing; do not hard-code real credentials.
4. Fail early with actionable error messages for missing prerequisites.

## OpenClaw Defaults

1. Keep gateway bind at `127.0.0.1`.
2. Keep default gateway port at `18789`.
3. Keep Docker volume paths stable: `openClaw/config -> /home/node/.openclaw` and `openClaw/workspace -> /home/node/.openclaw/workspace`.
4. Ensure `openClaw/config/openclaw.json` exists with local Control UI token auth enabled for localhost workflows.
5. For Telegram quick-start, default DM auth should allow local testing (`allowFrom=["*"]`, `dmPolicy=allowlist`).

## Verification

1. Run setup scripts after edits when possible.
2. Confirm containers are running with Docker Compose status commands.
3. Document any manual prerequisites in `README.md`.
4. For channel helpers (for example Telegram), validate via `openclaw channels list` and `openclaw channels status --probe`.
