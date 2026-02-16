@echo off
setlocal EnableExtensions
color 0A
title OpenClaw Run

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "ENV_FILE=%SCRIPT_DIR%\.env"
set "COMPOSE_FILE=%SCRIPT_DIR%\docker-compose.yml"
set "OPENCLAW_GATEWAY_TOKEN_VALUE="

echo.
echo ============================================================================
echo OpenClaw Run
echo ============================================================================
echo.

if not exist "%ENV_FILE%" (
    echo ERROR: Missing %ENV_FILE%
    echo Run setup-sandbox.bat first.
    pause
    exit /b 1
)

if not exist "%COMPOSE_FILE%" (
    echo ERROR: Missing %COMPOSE_FILE%
    echo Run setup-sandbox.bat first.
    pause
    exit /b 1
)

docker --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker is not installed or not in PATH.
    pause
    exit /b 1
)

docker info >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker daemon is not running.
    echo Start Docker Desktop and retry.
    pause
    exit /b 1
)

docker compose version >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker Compose is not available.
    pause
    exit /b 1
)

pushd "%SCRIPT_DIR%"
echo [*] Starting OpenClaw...
docker compose --env-file .env up -d
if %errorLevel% neq 0 (
    echo ERROR: Failed to start OpenClaw.
    popd
    pause
    exit /b 1
)

echo.
echo [*] Container status:
docker compose --env-file .env ps

for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    if /I "%%A"=="OPENCLAW_GATEWAY_TOKEN" set "OPENCLAW_GATEWAY_TOKEN_VALUE=%%B"
)
popd

echo.
echo [OK] OpenClaw is started (if image pull/start succeeded).
echo Gateway: http://127.0.0.1:18789
if not "%OPENCLAW_GATEWAY_TOKEN_VALUE%"=="" (
    echo Dashboard with token: http://127.0.0.1:18789/#token=%OPENCLAW_GATEWAY_TOKEN_VALUE%
    echo If UI says unauthorized, open the tokenized URL above.
) else (
    echo WARNING: OPENCLAW_GATEWAY_TOKEN not found in .env
    echo Generate token with setup-sandbox.bat or openclaw doctor --generate-gateway-token
)
echo Logs: docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env logs -f
echo.
pause
exit /b 0
