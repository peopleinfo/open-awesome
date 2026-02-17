#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: Node.js is required. Install Node.js 20+ and retry."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is required. Install npm and retry."
  exit 1
fi

if [[ ! -f ".env" && -f ".env.example" ]]; then
  cp .env.example .env
  echo "[*] Created .env from .env.example"
fi

if [[ ! -d "node_modules" ]]; then
  echo "[*] Installing dependencies..."
  npm install
fi

export ZERO_CLAW_API_HOST="${ZERO_CLAW_API_HOST:-127.0.0.1}"
export ZERO_CLAW_API_PORT="${ZERO_CLAW_API_PORT:-3010}"
export ZERO_CLAW_API_URL="${ZERO_CLAW_API_URL:-http://127.0.0.1:3010}"

echo "[*] Starting API + Electron dashboard..."
npm run dev
