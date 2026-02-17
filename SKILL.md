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
3. Keep localhost forwards `127.0.0.1:42000 -> 42000` (Pinokio web) and `127.0.0.1:30001 -> 30001` (container API docs/workflows).
4. Keep Docker volume paths stable: `openClaw/config -> /home/node/.openclaw` and `openClaw/workspace -> /home/node/.openclaw/workspace`.
5. Ensure `openClaw/config/openclaw.json` exists with local Control UI token auth enabled for localhost workflows.
6. For Telegram quick-start, default DM auth should allow local testing (`allowFrom=["*"]`, `dmPolicy=allowlist`).
7. For Pinokio host workflows, use `openClaw/pinokio-host.bat` so lifecycle and readiness checks are repeatable.
8. Normalize Pinokio config home paths to Linux container paths before launching from Windows-hosted workspaces.
9. Keep Pinokio runtime data on Docker volumes (for example `/pinokio-data`) instead of Windows bind mounts when conda/bootstrap is slow or stuck.
10. Keep `openClaw/run.bat` and `openClaw/pinokio-host.bat` compatible with unattended startup (`auto`, `--wait-pinokio`, `--wait-ready`, `--no-pause`).
11. Keep `openClaw/run.bat` no-arg default equivalent to `auto --wait-pinokio 240` and preserve `--manual` for interactive use.

## Verification

1. Run setup scripts after edits when possible.
2. Confirm containers are running with Docker Compose status commands.
3. Document any manual prerequisites in `README.md`.
4. For channel helpers (for example Telegram), validate via `openclaw channels list` and `openclaw channels status --probe`.
5. For Codex OAuth helper changes, validate quick probe behavior and verify recovery messaging for refresh-token failures.
6. For Codex OAuth helper changes, validate account switch flow (`--re-auth`) imports the newly selected host account.
7. For Pinokio host helper changes, validate `start`, `status`, and host URL reachability on `http://localhost:42000`.
8. For startup automation changes, validate `openClaw\run.bat auto --wait-pinokio 240` can run without interactive prompts.
