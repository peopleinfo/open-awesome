---
name: open-awesome-bootstrap
description: Bootstrap and maintain this repository for programming, AI, agent, and LLM tooling with secure local setup automation. Use when creating or updating core project scaffolding, setup scripts, and agent workflow docs (README.md, AGENTS.md, SKILL.md, and OpenClaw setup files).
---

# Open Awesome Bootstrap Workflow

## Keep Core Files In Sync

1. Update `README.md` when startup commands or structure changes.
2. Update `AGENTS.md` when execution rules or safety expectations change.
3. Keep this file focused on reusable, procedural guidance.
4. When docs reference output/workspace folders, include Windows and Linux examples using `<repo_root>` placeholders (no hard-coded usernames).

## Setup Script Standards

1. Make scripts safe-by-default and idempotent.
2. Bind services to localhost unless explicitly required otherwise.
3. Generate secrets at runtime when missing; do not hard-code real credentials.
4. Fail early with actionable error messages for missing prerequisites.
5. For OAuth bootstrap helpers, include bounded retry and clear re-auth instructions when refresh tokens are invalidated.
6. Provide an explicit account-switch re-auth path (for example a `--re-auth` style option) before token import.

## OpenClaw Defaults

1. Keep gateway bind at `127.0.0.1`.
2. Keep default gateway port at `18789`.
3. Keep localhost forwards `127.0.0.1:42000 -> 42000` (Pinokio web), `127.0.0.1:30001 -> 30001` (container API docs/workflows), and `127.0.0.1:30110 -> 30110` (camoufox profile manager API).
4. Keep Docker volume paths stable: `openClaw/config -> /home/node/.openclaw` and `openClaw/workspace -> /home/node/.openclaw/workspace`.
5. Keep a persistent sandbox Git identity config at `openClaw/config/gitconfig` and map it as global Git config in container so Telegram/agent `git commit` works unattended.
6. Ensure `openClaw/config/openclaw.json` exists with local Control UI token auth enabled for localhost workflows.
7. For Telegram quick-start, default DM auth should allow local testing (`allowFrom=["*"]`, `dmPolicy=allowlist`).
8. For Pinokio host workflows, use `openClaw/pinokio-host.bat` so lifecycle and readiness checks are repeatable.
9. Normalize Pinokio config home paths to Linux container paths before launching from Windows-hosted workspaces.
10. Keep Pinokio runtime data on Docker volumes (for example `/pinokio-data`) instead of Windows bind mounts when conda/bootstrap is slow or stuck.
11. Keep `openClaw/run.bat` and `openClaw/pinokio-host.bat` compatible with unattended startup (`auto`, `--wait-pinokio`, `--wait-ready`, `--no-pause`).
12. Keep `openClaw/run.bat` no-arg default equivalent to `auto --wait-pinokio 240` and preserve `--manual` for interactive use.
13. For Camoufox browser workflows, enforce profile/state through:
    - Windows: `<repo_root>\openClaw\workspace\pinokio-data\api\camoufox-mgt`
    - Linux: `<repo_root>/openClaw/workspace/pinokio-data/api/camoufox-mgt`
14. Use `skills/camoufox-mgt-enforcer/SKILL.md` for agent instructions that require Camoufox-only browser automation.

## Zero Claw Starter Defaults

1. Keep `zero-claw` API bind local-only (`127.0.0.1`) unless explicit public exposure is requested.
2. Keep default API port at `3010`.
3. Keep Todo data local and gitignored (`zero-claw/data/todos.json`).
4. Keep secrets local and gitignored (`zero-claw/.env`), with `.env.example` for template-only values.
5. Keep setup state local and gitignored (`zero-claw/data/settings.json`) for first-run wizard flows.
6. Ensure desktop UI and Telegram command handlers operate on the same CRUD store.
7. Keep desktop navigation modular so Todo is a sample module and new modules can be added incrementally.
8. Keep end-user startup simple with both Windows and Linux entrypoints (`zero-claw/run.bat`, `zero-claw/run.sh`).
9. Prefer GUI-first operations for end users by exposing common `zeroclaw` runtime actions in the desktop app.
10. Enforce readiness gating so users complete required setup before accessing non-setup modules.
11. Keep Telegram webhook URL optional by default in readiness gates unless a strict webhook policy is explicitly requested.
12. Provide a GUI install path for ZeroClaw CLI and surface installer logs/errors in Setup Wizard.
13. Provide GUI support to apply Codex defaults in zeroclaw config (`default_provider=openai`, `default_model=gpt-5.2-codex`) without terminal use.
14. Keep Agent Prompt usable without `OPENAI_API_KEY` by falling back to Codex OAuth (`codex login`) when zeroclaw provider auth fails.

## Verification

1. Run setup scripts after edits when possible.
2. Confirm containers are running with Docker Compose status commands.
3. Document any manual prerequisites in `README.md`.
4. For channel helpers (for example Telegram), validate via `openclaw channels list` and `openclaw channels status --probe`.
5. For Codex OAuth helper changes, validate quick probe behavior and verify recovery messaging for refresh-token failures.
6. For Codex OAuth helper changes, validate account switch flow (`--re-auth`) imports the newly selected host account.
7. For Pinokio host helper changes, validate `start`, `status`, and host URL reachability on `http://localhost:42000`.
8. For startup automation changes, validate `openClaw\run.bat auto --wait-pinokio 240` can run without interactive prompts.
9. For Zero Claw changes, validate `zero-claw` startup scripts run, `GET /health` returns success, setup endpoints respond (including Codex-default checks), and Agent module endpoints return structured status.
