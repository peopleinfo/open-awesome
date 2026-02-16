#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./skill.sh init <name> [file]
  ./skill.sh init security-check [skill-dir/SKILL.md]
  ./skill.sh validate [file]

Examples:
  ./skill.sh init open-awesome-bootstrap
  ./skill.sh init security-check
  ./skill.sh validate SKILL.md
EOF
}

write_security_check_runner() {
  local script_file="$1"

  cat >"${script_file}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

TARGET_INPUT="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_ALLOWED_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd -P)"
ALLOWED_ROOT="${DEFAULT_ALLOWED_ROOT}"

if [[ ! -d "${TARGET_INPUT}" ]]; then
  echo "Error: target directory not found: ${TARGET_INPUT}" >&2
  exit 1
fi

if command -v realpath >/dev/null 2>&1; then
  TARGET_DIR="$(realpath "${TARGET_INPUT}")"
else
  TARGET_DIR="$(cd "${TARGET_INPUT}" && pwd -P)"
fi

if command -v realpath >/dev/null 2>&1; then
  ALLOWED_ROOT="$(realpath "${ALLOWED_ROOT}")"
else
  ALLOWED_ROOT="$(cd "${ALLOWED_ROOT}" && pwd -P)"
fi

if [[ "${TARGET_DIR}" == "/" ]] || [[ "${TARGET_DIR}" =~ ^[A-Za-z]:/$ ]]; then
  echo "Error: refusing to scan filesystem root." >&2
  exit 1
fi

if [[ "${TARGET_DIR}" != "${ALLOWED_ROOT}" ]] && [[ "${TARGET_DIR}" != "${ALLOWED_ROOT}/"* ]]; then
  echo "Error: refusing to scan outside allowed root: ${ALLOWED_ROOT}" >&2
  exit 1
fi

case "${TARGET_DIR}" in
  /etc|/usr|/var|/bin|/sbin|/boot|/sys|/proc|/dev|/run|/root|/home)
    echo "Error: refusing to scan system directory: ${TARGET_DIR}" >&2
    exit 1
    ;;
esac

if [[ "${TARGET_DIR}" =~ ^[A-Za-z]:/(Windows|Program\ Files|ProgramData|Users)$ ]]; then
  echo "Error: refusing to scan Windows system root: ${TARGET_DIR}" >&2
  exit 1
fi

SCAN_TOOL=""
if command -v rg >/dev/null 2>&1; then
  SCAN_TOOL="rg"
elif command -v grep >/dev/null 2>&1; then
  SCAN_TOOL="grep"
else
  echo "Error: requires rg or grep." >&2
  exit 1
fi

FOUND=0

scan() {
  local title="$1"
  local pattern="$2"
  echo
  echo "== ${title} =="
  if [[ "${SCAN_TOOL}" == "rg" ]]; then
    if rg -n --hidden --no-ignore-vcs -S \
      --glob '!.git/*' \
      --glob '!node_modules/*' \
      --glob '!dist/*' \
      --glob '!build/*' \
      "${pattern}" "${TARGET_DIR}"; then
      FOUND=1
    else
      echo "No findings."
    fi
  else
    if grep -RInE --binary-files=without-match \
      --exclude-dir=.git \
      --exclude-dir=node_modules \
      --exclude-dir=dist \
      --exclude-dir=build \
      "${pattern}" "${TARGET_DIR}"; then
      FOUND=1
    else
      echo "No findings."
    fi
  fi
}

echo "Running read-only security checks in: ${TARGET_DIR}"

scan "Potential hardcoded secrets" \
  '(OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY)'

scan "Unsafe container flags" \
  '(privileged:\s*true|network_mode:\s*host|--privileged|/var/run/docker\.sock)'

scan "Public bind defaults" \
  '(OPENCLAW_HOST_BIND\s*=\s*0\.0\.0\.0|OPENCLAW_GATEWAY_BIND\s*=\s*(auto|custom))'

scan "Dangerous shell patterns" \
  '(rm\s+-rf\s+/|git\s+reset\s+--hard|docker\s+system\s+prune\s+-a|curl\s+.*\|\s*(sh|bash|powershell))'

echo
if [[ "${FOUND}" -eq 0 ]]; then
  echo "Security check passed: no risky patterns found."
else
  echo "Security check found risky patterns. Review findings before running."
fi
EOF

  chmod +x "${script_file}"
}

init_security_check_skill() {
  local file="$1"
  local skill_dir
  local script_file

  mkdir -p "$(dirname "${file}")"
  skill_dir="$(cd "$(dirname "${file}")" && pwd -P)"
  mkdir -p "${skill_dir}/scripts"
  script_file="${skill_dir}/scripts/security-check.sh"

  cat >"${file}" <<'EOF'
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
EOF

  write_security_check_runner "${script_file}"
  echo "Created ${file}"
  echo "Created ${script_file}"
}

init_skill() {
  local name="${1:-}"
  local file="${2:-}"

  if [[ -z "${name}" ]]; then
    echo "Error: skill name is required."
    usage
    exit 1
  fi

  if [[ -z "${file}" ]]; then
    if [[ "${name}" == "security-check" ]]; then
      file="skills/security-check/SKILL.md"
    else
      file="SKILL.md"
    fi
  fi

  if [[ "${name}" == "security-check" ]]; then
    init_security_check_skill "${file}"
    return
  fi

  mkdir -p "$(dirname "${file}")"
  cat >"${file}" <<EOF
---
name: ${name}
description: Describe what this skill does and when to use it.
---

# ${name}

## Workflow

1. Add concise reusable instructions.
2. Keep setup defaults secure.
3. Reference scripts/resources only when needed.
EOF

  echo "Created ${file}"
}

validate_skill() {
  local file="${1:-SKILL.md}"

  if [[ ! -f "${file}" ]]; then
    echo "Error: ${file} not found."
    exit 1
  fi

  if ! grep -q '^---$' "${file}"; then
    echo "Invalid: missing YAML frontmatter markers."
    exit 1
  fi

  if ! grep -q '^name: ' "${file}"; then
    echo "Invalid: missing required 'name' field."
    exit 1
  fi

  if ! grep -q '^description: ' "${file}"; then
    echo "Invalid: missing required 'description' field."
    exit 1
  fi

  echo "Valid: ${file}"
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    init)
      shift
      init_skill "${1:-}" "${2:-}"
      ;;
    validate)
      shift
      validate_skill "${1:-SKILL.md}"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
