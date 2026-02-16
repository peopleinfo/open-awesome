@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 0A
title OpenClaw Safe Setup

echo.
echo ============================================================================
echo OpenClaw Safe Setup with Docker Sandboxing
echo ============================================================================
echo.

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "ENV_FILE=%SCRIPT_DIR%\.env"
set "COMPOSE_FILE=%SCRIPT_DIR%\docker-compose.yml"
set "CONFIG_FILE=%SCRIPT_DIR%\config\openclaw.json"
set "DEFAULT_OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest"

REM Check if running as Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please run Command Prompt as Administrator.
    pause
    exit /b 1
)

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker Desktop is not installed or not in PATH.
    echo Install from: https://www.docker.com/products/docker-desktop
    echo Then restart this script.
    pause
    exit /b 1
)

echo [OK] Docker is installed
docker --version

REM Check if Docker daemon is running
docker info >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker daemon is not running.
    echo Start Docker Desktop and wait until it is fully initialized.
    pause
    exit /b 1
)

REM Check if Docker Compose is available
docker compose version >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker Compose not found.
    echo Ensure Docker Desktop is fully installed.
    pause
    exit /b 1
)

echo [OK] Docker Compose is available
docker compose version
echo.

REM Create directory structure
echo [*] Creating OpenClaw directories...
if not exist "%USERPROFILE%\.openclaw" mkdir "%USERPROFILE%\.openclaw"
if not exist "%USERPROFILE%\.openclaw\workspace" mkdir "%USERPROFILE%\.openclaw\workspace"
if not exist "%SCRIPT_DIR%\config" mkdir "%SCRIPT_DIR%\config"
if not exist "%SCRIPT_DIR%\workspace" mkdir "%SCRIPT_DIR%\workspace"
echo [OK] Directories created
echo.

if exist "%CONFIG_FILE%" (
    echo [*] Existing openclaw.json found. Keeping current values.
) else (
    echo [*] Creating openclaw.json for local Control UI token auth...
    (
        echo {
        echo   "gateway": {
        echo     "mode": "local",
        echo     "controlUi": {
        echo       "allowInsecureAuth": true
        echo     }
        echo   }
        echo }
    ) > "%CONFIG_FILE%"
    echo [OK] openclaw.json created
)
echo.

REM Create .env file with security defaults if missing
if exist "%ENV_FILE%" (
    echo [*] Existing .env found. Keeping current values.
) else (
    echo [*] Creating .env file with secure defaults...
    for /f %%G in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString().Replace(\"-\",\"\")"') do set "OPENCLAW_TOKEN=%%G"
    for /f %%G in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString().Replace(\"-\",\"\")"') do set "GOG_KEYRING_PASSWORD=%%G"

    (
        echo OPENCLAW_IMAGE=%DEFAULT_OPENCLAW_IMAGE%
        echo OPENCLAW_HOST_BIND=127.0.0.1
        echo OPENCLAW_GATEWAY_BIND=lan
        echo OPENCLAW_GATEWAY_PORT=18789
        echo OPENCLAW_GATEWAY_TOKEN=!OPENCLAW_TOKEN!
        echo GOG_KEYRING_PASSWORD=!GOG_KEYRING_PASSWORD!
    ) > "%ENV_FILE%"

    echo [OK] .env created
)
echo.

set "OPENCLAW_IMAGE_VALUE="
set "OPENCLAW_HOST_BIND_VALUE="
set "OPENCLAW_GATEWAY_BIND_VALUE="
for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    if /I "%%A"=="OPENCLAW_IMAGE" set "OPENCLAW_IMAGE_VALUE=%%B"
    if /I "%%A"=="OPENCLAW_HOST_BIND" set "OPENCLAW_HOST_BIND_VALUE=%%B"
    if /I "%%A"=="OPENCLAW_GATEWAY_BIND" set "OPENCLAW_GATEWAY_BIND_VALUE=%%B"
)

if /I "!OPENCLAW_IMAGE_VALUE!"=="openclaw:latest" (
    echo [*] Detected legacy image value "openclaw:latest". Migrating to "%DEFAULT_OPENCLAW_IMAGE%"...
    powershell -NoProfile -Command "(Get-Content -Raw '%ENV_FILE%') -replace '(?m)^OPENCLAW_IMAGE=.*$','OPENCLAW_IMAGE=%DEFAULT_OPENCLAW_IMAGE%' | Set-Content '%ENV_FILE%'"
    if !errorLevel! neq 0 (
        echo ERROR: Failed to update OPENCLAW_IMAGE in .env
        pause
        exit /b 1
    )
    echo [OK] OPENCLAW_IMAGE updated
)
echo.

if "!OPENCLAW_HOST_BIND_VALUE!"=="" (
    echo [*] OPENCLAW_HOST_BIND not found. Setting host bind to 127.0.0.1...
    powershell -NoProfile -Command "Add-Content -Path '%ENV_FILE%' -Value 'OPENCLAW_HOST_BIND=127.0.0.1'"
    if !errorLevel! neq 0 (
        echo ERROR: Failed to add OPENCLAW_HOST_BIND to .env
        pause
        exit /b 1
    )
    echo [OK] OPENCLAW_HOST_BIND added
)

if /I "!OPENCLAW_GATEWAY_BIND_VALUE!"=="127.0.0.1" (
    echo [*] Detected legacy OPENCLAW_GATEWAY_BIND=127.0.0.1. Migrating to bind mode "lan"...
    powershell -NoProfile -Command "(Get-Content -Raw '%ENV_FILE%') -replace '(?m)^OPENCLAW_GATEWAY_BIND=.*$','OPENCLAW_GATEWAY_BIND=lan' | Set-Content '%ENV_FILE%'"
    if !errorLevel! neq 0 (
        echo ERROR: Failed to migrate OPENCLAW_GATEWAY_BIND in .env
        pause
        exit /b 1
    )
    echo [OK] OPENCLAW_GATEWAY_BIND migrated
)

if /I "!OPENCLAW_GATEWAY_BIND_VALUE!"=="0.0.0.0" (
    echo [*] Detected legacy OPENCLAW_GATEWAY_BIND=0.0.0.0. Migrating to bind mode "lan"...
    powershell -NoProfile -Command "(Get-Content -Raw '%ENV_FILE%') -replace '(?m)^OPENCLAW_GATEWAY_BIND=.*$','OPENCLAW_GATEWAY_BIND=lan' | Set-Content '%ENV_FILE%'"
    if !errorLevel! neq 0 (
        echo ERROR: Failed to migrate OPENCLAW_GATEWAY_BIND in .env
        pause
        exit /b 1
    )
    echo [OK] OPENCLAW_GATEWAY_BIND migrated
)
echo.

set "REWRITE_COMPOSE="
if exist "%COMPOSE_FILE%" (
    findstr /C:"./config:/app/config" "%COMPOSE_FILE%" >nul 2>&1 && set "REWRITE_COMPOSE=1"
    findstr /C:"./workspace:/workspace" "%COMPOSE_FILE%" >nul 2>&1 && set "REWRITE_COMPOSE=1"
    if defined REWRITE_COMPOSE (
        echo [*] Detected legacy docker-compose.yml. Migrating volume mounts and auth args...
    ) else (
        echo [*] Existing docker-compose.yml found. Keeping current file.
    )
) else (
    set "REWRITE_COMPOSE=1"
    echo [*] Creating docker-compose.yml...
)

if defined REWRITE_COMPOSE (
    call :write_compose
    if !errorLevel! neq 0 (
        echo ERROR: Failed to write docker-compose.yml
        pause
        exit /b 1
    )
    echo [OK] docker-compose.yml written
)
echo.

pushd "%SCRIPT_DIR%"

echo [*] Pulling latest image...
docker compose pull
if %errorLevel% neq 0 (
    echo ERROR: Failed to pull image.
    echo Check network, Docker login state, and OPENCLAW_IMAGE value in .env.
    echo Suggested image: %DEFAULT_OPENCLAW_IMAGE%
    popd
    pause
    exit /b 1
)

echo [*] Starting OpenClaw...
docker compose up -d
if %errorLevel% neq 0 (
    echo ERROR: Failed to start OpenClaw container.
    popd
    pause
    exit /b 1
)

docker compose ps
popd

echo.
echo [OK] OpenClaw setup is complete.
echo Gateway: http://127.0.0.1:18789
echo.
echo Next steps:
echo 1. Open .env and rotate tokens if needed.
echo 2. Use "docker compose -f openClaw\docker-compose.yml logs -f" to watch startup logs.
echo 3. Run openClaw\run.bat for normal startup.
echo.
pause
exit /b 0

:write_compose
(
    echo services:
    echo   openclaw:
    echo     image: ${OPENCLAW_IMAGE}
    echo     container_name: openclaw
    echo     restart: unless-stopped
    echo     command:
    echo       - node
    echo       - /app/openclaw.mjs
    echo       - gateway
    echo       - --allow-unconfigured
    echo       - --auth
    echo       - token
    echo       - --token
    echo       - ${OPENCLAW_GATEWAY_TOKEN}
    echo       - --bind
    echo       - ${OPENCLAW_GATEWAY_BIND}
    echo       - --port
    echo       - ${OPENCLAW_GATEWAY_PORT}
    echo     env_file:
    echo       - .env
    echo     environment:
    echo       - HOME=/home/node
    echo       - OPENCLAW_HOST_BIND=${OPENCLAW_HOST_BIND}
    echo       - OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND}
    echo       - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT}
    echo       - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
    echo       - GOG_KEYRING_PASSWORD=${GOG_KEYRING_PASSWORD}
    echo     ports:
    echo       - "${OPENCLAW_HOST_BIND}:${OPENCLAW_GATEWAY_PORT}:${OPENCLAW_GATEWAY_PORT}"
    echo       - "${OPENCLAW_HOST_BIND}:42000:42000"
    echo       - "${OPENCLAW_HOST_BIND}:30001:30001"
    echo     volumes:
    echo       - ./config:/home/node/.openclaw
    echo       - ./workspace:/home/node/.openclaw/workspace
    echo       - pinokio_data:/pinokio-data
    echo.
    echo volumes:
    echo   pinokio_data:
) > "%COMPOSE_FILE%"
exit /b %errorLevel%
