#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_SETUP_BAT="${ROOT_DIR}/openClaw/setup-sandbox.bat"
OPENCLAW_OAUTH_BAT="${ROOT_DIR}/openClaw/apply-openai-oauth.bat"

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
  if command -v docker >/dev/null 2>&1; then
    if docker --version >/dev/null 2>&1; then
      echo "Docker is already installed. Skipping install/update."
      return 0
    fi
  fi

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

apply_openai_oauth() {
  if [[ ! -f "${OPENCLAW_OAUTH_BAT}" ]]; then
    echo "Error: ${OPENCLAW_OAUTH_BAT} not found."
    return 1
  fi
  if ! command -v powershell.exe >/dev/null 2>&1; then
    echo "Error: powershell.exe is required on Windows."
    return 1
  fi

  local oauth_win
  oauth_win="$(to_windows_path "${OPENCLAW_OAUTH_BAT}")"

  echo "Launching OpenAI OAuth apply script..."
  powershell.exe -NoProfile -Command "Start-Process -Wait -FilePath '${oauth_win}'"
  echo "OpenAI OAuth apply script finished."
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
1) Install Docker Desktop (optional)
   - Skips automatically if Docker is already installed.
2) Setup OpenClaw sandbox
   - Runs openClaw/setup-sandbox.bat with admin prompt.
3) Apply OpenAI OAuth (Codex)
   - Reuses local Codex auth and imports into OpenClaw.
4) Check install status
   - Shows Docker and OpenClaw file status.
5) Help (full option details)
6) Exit
EOF
}

print_help() {
  cat <<'EOF'

Menu Details
------------
1) Install Docker Desktop
   Run:
   winget install -e --id Docker.DockerDesktop

2) Setup OpenClaw sandbox
   Run:
   openClaw/setup-sandbox.bat
   This creates .env, compose file, and starts container.

3) Apply OpenAI OAuth (Codex)
   Run:
   openClaw/apply-openai-oauth.bat
   This imports ~/.codex/auth.json into OpenClaw auth-profiles.

4) Check install status
   Run:
   docker --version
   docker compose version
   and verify openClaw/setup-sandbox.bat exists.

5) Help
   Show this detailed explanation.

6) Exit
   Close this menu.
EOF
}

main() {
  while true; do
    print_menu
    read -r -p "Pick an option [1-6]: " choice
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
        apply_openai_oauth || true
        pause
        ;;
      4)
        show_status
        pause
        ;;
      5)
        print_help
        pause
        ;;
      6)
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
