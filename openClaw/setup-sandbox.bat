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

REM Create .env file with security defaults if missing
if exist "%ENV_FILE%" (
    echo [*] Existing .env found. Keeping current values.
) else (
    echo [*] Creating .env file with secure defaults...
    for /f %%G in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString().Replace(\"-\",\"\")"') do set "OPENCLAW_TOKEN=%%G"
    for /f %%G in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString().Replace(\"-\",\"\")"') do set "GOG_KEYRING_PASSWORD=%%G"

    (
        echo OPENCLAW_IMAGE=openclaw:latest
        echo OPENCLAW_GATEWAY_BIND=127.0.0.1
        echo OPENCLAW_GATEWAY_PORT=18789
        echo OPENCLAW_GATEWAY_TOKEN=!OPENCLAW_TOKEN!
        echo GOG_KEYRING_PASSWORD=!GOG_KEYRING_PASSWORD!
    ) > "%ENV_FILE%"

    echo [OK] .env created
)
echo.

REM Create compose file when missing
if exist "%COMPOSE_FILE%" (
    echo [*] Existing docker-compose.yml found. Keeping current file.
) else (
    echo [*] Creating docker-compose.yml...
    (
        echo services:
        echo   openclaw:
        echo     image: ${OPENCLAW_IMAGE}
        echo     container_name: openclaw
        echo     restart: unless-stopped
        echo     env_file:
        echo       - .env
        echo     environment:
        echo       - OPENCLAW_GATEWAY_BIND=${OPENCLAW_GATEWAY_BIND}
        echo       - OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT}
        echo       - OPENCLAW_GATEWAY_TOKEN=${OPENCLAW_GATEWAY_TOKEN}
        echo       - GOG_KEYRING_PASSWORD=${GOG_KEYRING_PASSWORD}
        echo     ports:
        echo       - "${OPENCLAW_GATEWAY_BIND}:${OPENCLAW_GATEWAY_PORT}:${OPENCLAW_GATEWAY_PORT}"
        echo     volumes:
        echo       - ./config:/app/config
        echo       - ./workspace:/workspace
    ) > "%COMPOSE_FILE%"
    echo [OK] docker-compose.yml created
)
echo.

pushd "%SCRIPT_DIR%"

echo [*] Pulling latest image...
docker compose pull
if %errorLevel% neq 0 (
    echo ERROR: Failed to pull image. Check internet and image name in .env.
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
echo.
pause
exit /b 0
