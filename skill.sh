#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./skill.sh init <name> [file]
  ./skill.sh validate [file]

Examples:
  ./skill.sh init open-awesome-bootstrap
  ./skill.sh validate SKILL.md
EOF
}

init_skill() {
  local name="${1:-}"
  local file="${2:-SKILL.md}"

  if [[ -z "${name}" ]]; then
    echo "Error: skill name is required."
    usage
    exit 1
  fi

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
      init_skill "${1:-}" "${2:-SKILL.md}"
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
