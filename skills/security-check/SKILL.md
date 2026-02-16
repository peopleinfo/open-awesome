---
name: security-check
description: Run safe, read-only security checks for local project files. Use when auditing configs, scripts, and secrets exposure without modifying system state, installing software, or touching host-level services.
---

# security-check

## Safety Boundaries

1. Operate only on the target project directory.
2. Keep all scans inside the repository root by default.
3. Run read-only checks only.
4. Do not run privileged commands (`sudo`, `runas`, registry/service edits).
5. Do not execute destructive commands (`rm`, `del`, `format`, `git reset --hard`, `docker system prune`).
6. Redact secret values in output (show location only).

## Workflow

1. Run `scripts/security-check.sh <project-path>` from this skill folder.
2. Review findings by severity and file location.
3. Propose minimal fixes first; apply changes only with explicit approval.
