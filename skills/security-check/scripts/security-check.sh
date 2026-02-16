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
