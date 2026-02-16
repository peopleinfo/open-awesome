#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_SETUP_BAT="${ROOT_DIR}/openClaw/setup-sandbox.bat"

to_windows_path() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "${path}"
    return
  fi
  if command -v wslpath >/dev/null 2>&1; then
    wslpath -w "${path}"
    return
  fi
  printf "%s\n" "${path}"
}

pause() {
  read -r -p "Press Enter to continue..."
}

install_docker_desktop() {
  if ! command -v powershell.exe >/dev/null 2>&1; then
    echo "Error: powershell.exe is required on Windows."
    return 1
  fi

  echo "Starting Docker Desktop installation via winget (Admin prompt expected)..."
  powershell.exe -NoProfile -Command "Start-Process -Verb RunAs -Wait -FilePath 'winget' -ArgumentList 'install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements'"
  echo "Docker Desktop install command finished."
}

run_openclaw_setup() {
  if [[ ! -f "${OPENCLAW_SETUP_BAT}" ]]; then
    echo "Error: ${OPENCLAW_SETUP_BAT} not found."
    return 1
  fi
  if ! command -v powershell.exe >/dev/null 2>&1; then
    echo "Error: powershell.exe is required on Windows."
    return 1
  fi

  local setup_win
  setup_win="$(to_windows_path "${OPENCLAW_SETUP_BAT}")"

  echo "Launching OpenClaw setup (Admin prompt expected)..."
  powershell.exe -NoProfile -Command "Start-Process -Verb RunAs -Wait -FilePath '${setup_win}'"
  echo "OpenClaw setup finished."
}

show_status() {
  echo
  echo "Docker version:"
  if command -v docker >/dev/null 2>&1; then
    docker --version || true
    docker compose version || true
  else
    echo "docker not found in PATH."
  fi

  echo
  echo "OpenClaw files:"
  if [[ -f "${OPENCLAW_SETUP_BAT}" ]]; then
    echo "Found: ${OPENCLAW_SETUP_BAT}"
  else
    echo "Missing: ${OPENCLAW_SETUP_BAT}"
  fi
}

print_menu() {
  cat <<'EOF'
========================================
Open Awesome Installer Menu
========================================
1) Install Docker Desktop
2) Install/OpenClaw setup sandbox
3) Check install status
4) Exit
EOF
}

main() {
  while true; do
    print_menu
    read -r -p "Pick an option [1-4]: " choice
    case "${choice}" in
      1)
        install_docker_desktop || true
        pause
        ;;
      2)
        run_openclaw_setup || true
        pause
        ;;
      3)
        show_status
        pause
        ;;
      4)
        echo "Bye."
        exit 0
        ;;
      *)
        echo "Invalid option: ${choice}"
        pause
        ;;
    esac
    echo
  done
}

main "$@"
