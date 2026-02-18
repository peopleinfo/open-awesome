@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 0A
title OpenClaw Run

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "ENV_FILE=%SCRIPT_DIR%\.env"
set "COMPOSE_FILE=%SCRIPT_DIR%\docker-compose.yml"
set "CONFIG_DIR=%SCRIPT_DIR%\config"
set "GITCONFIG_FILE=%CONFIG_DIR%\gitconfig"
set "WORKSPACE_DIR=%SCRIPT_DIR%\workspace"
set "OPENCLAW_CONFIG_FILE=%CONFIG_DIR%\openclaw.json"
set "OPENCLAW_GATEWAY_TOKEN_VALUE="

set "AUTO_MODE=1"
set "PAUSE_ON_EXIT=0"
set "START_PINOKIO=1"
set "WAIT_PINOKIO_SECONDS=240"
set "EXIT_CODE=0"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="auto" goto arg_auto
if /I "%~1"=="--auto" goto arg_auto
if /I "%~1"=="--manual" goto arg_manual
if /I "%~1"=="--start-pinokio" goto arg_start_pinokio
if /I "%~1"=="--wait-pinokio" goto parse_wait_pinokio
if /I "%~1"=="--no-pause" goto arg_no_pause
if /I "%~1"=="--help" goto arg_help
if /I "%~1"=="-h" goto arg_help
echo ERROR: Unknown argument "%~1"
set "USAGE_EXIT_CODE=1"
goto usage

:arg_auto
set "AUTO_MODE=1"
set "PAUSE_ON_EXIT=0"
set "START_PINOKIO=1"
shift
goto parse_args

:arg_manual
set "AUTO_MODE=0"
set "PAUSE_ON_EXIT=1"
set "START_PINOKIO=0"
shift
goto parse_args

:arg_start_pinokio
set "START_PINOKIO=1"
shift
goto parse_args

:arg_no_pause
set "PAUSE_ON_EXIT=0"
shift
goto parse_args

:arg_help
set "USAGE_EXIT_CODE=0"
goto usage

:parse_wait_pinokio
shift
if "%~1"=="" (
    echo ERROR: --wait-pinokio requires a seconds value.
    set "USAGE_EXIT_CODE=1"
    goto usage
)
set "WAIT_PINOKIO_SECONDS=%~1"
shift
goto parse_args

:args_done
echo.
echo ============================================================================
echo OpenClaw Run
echo ============================================================================
echo.
if "%AUTO_MODE%"=="1" (
    echo [*] Mode: unattended startup
) else (
    echo [*] Mode: interactive
)
echo.

if not exist "%ENV_FILE%" (
    echo ERROR: Missing %ENV_FILE%
    echo Run setup-sandbox.bat first.
    call :maybe_pause
    exit /b 1
)

if not exist "%COMPOSE_FILE%" (
    echo ERROR: Missing %COMPOSE_FILE%
    echo Run setup-sandbox.bat first.
    call :maybe_pause
    exit /b 1
)

if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
if not exist "%WORKSPACE_DIR%" mkdir "%WORKSPACE_DIR%"
if not exist "%GITCONFIG_FILE%" (
    echo [*] Creating %GITCONFIG_FILE% with default local Git author...
    (
        echo [user]
        echo     name = OpenClaw Local Agent
        echo     email = openclaw-local@localhost
    ) > "%GITCONFIG_FILE%"
)

if not exist "%OPENCLAW_CONFIG_FILE%" (
    echo [*] Creating %OPENCLAW_CONFIG_FILE% for local Control UI auth...
    (
        echo {
        echo   "gateway": {
        echo     "mode": "local",
        echo     "controlUi": {
        echo       "allowInsecureAuth": true
        echo     }
        echo   }
        echo }
    ) > "%OPENCLAW_CONFIG_FILE%"
)

docker --version >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker is not installed or not in PATH.
    call :maybe_pause
    exit /b 1
)

call :wait_for_docker 120
if errorlevel 1 (
    echo ERROR: Docker daemon is not ready.
    echo Start Docker Desktop and retry.
    call :maybe_pause
    exit /b 1
)

docker compose version >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Docker Compose is not available.
    call :maybe_pause
    exit /b 1
)

pushd "%SCRIPT_DIR%"
echo [*] Starting OpenClaw...
docker compose --env-file .env up -d
if %errorLevel% neq 0 (
    echo ERROR: Failed to start OpenClaw.
    popd
    call :maybe_pause
    exit /b 1
)

echo.
echo [*] Container status:
docker compose --env-file .env ps
call :ensure_git_identity

for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    if /I "%%A"=="OPENCLAW_GATEWAY_TOKEN" set "OPENCLAW_GATEWAY_TOKEN_VALUE=%%B"
)
popd

if "%START_PINOKIO%"=="1" (
    echo.
    echo [*] Auto-starting Pinokio web service...
    call "%SCRIPT_DIR%\pinokio-host.bat" start --no-pause --wait-ready !WAIT_PINOKIO_SECONDS!
    if errorlevel 1 (
        echo WARNING: Pinokio did not become ready on http://localhost:42000
        echo Check logs: openClaw\pinokio-host.bat logs
        set "EXIT_CODE=1"
    )
)

echo.
echo [OK] OpenClaw is started (if image pull/start succeeded).
echo Gateway: http://127.0.0.1:18789
if not "%OPENCLAW_GATEWAY_TOKEN_VALUE%"=="" (
    echo Dashboard with token: http://127.0.0.1:18789/#token=%OPENCLAW_GATEWAY_TOKEN_VALUE%
    echo If UI says "pairing required", run setup-sandbox.bat once to migrate legacy config mounts.
) else (
    echo WARNING: OPENCLAW_GATEWAY_TOKEN not found in .env
    echo Generate token with setup-sandbox.bat or openclaw doctor --generate-gateway-token
)
if "%START_PINOKIO%"=="1" (
    echo Pinokio: http://localhost:42000
)
echo Logs: docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env logs -f
echo.

call :maybe_pause
exit /b %EXIT_CODE%

:wait_for_docker
set /a MAX_WAIT=%~1
if "!MAX_WAIT!"=="" set /a MAX_WAIT=120
set /a WAITED=0
:wait_for_docker_loop
docker info >nul 2>&1
if !errorLevel! equ 0 exit /b 0
if !WAITED! geq !MAX_WAIT! exit /b 1
if !WAITED! equ 0 echo [*] Waiting for Docker daemon to be ready...
powershell -NoProfile -Command "Start-Sleep -Seconds 3" >nul 2>&1
set /a WAITED+=3
goto wait_for_docker_loop

:ensure_git_identity
docker exec openclaw sh -lc "git config --global user.name >/dev/null 2>&1 || git config --global user.name 'OpenClaw Local Agent'; git config --global user.email >/dev/null 2>&1 || git config --global user.email 'openclaw-local@localhost'" >nul 2>&1
if %errorLevel% neq 0 (
    echo WARNING: Could not verify Git identity inside openclaw container.
    echo Telegram git commits may fail until container git config is available.
) else (
    echo [OK] Git identity is configured for sandbox commits.
)
exit /b 0

:maybe_pause
if "%PAUSE_ON_EXIT%"=="1" pause
exit /b 0

:usage
if not defined USAGE_EXIT_CODE set "USAGE_EXIT_CODE=0"
echo Usage:
echo   openClaw\run.bat [auto^|--auto^|--manual] [--start-pinokio] [--wait-pinokio SECONDS] [--no-pause]
echo.
echo Examples:
echo   openClaw\run.bat    ^(default: auto --wait-pinokio 240^)
echo   openClaw\run.bat --manual
echo   openClaw\run.bat auto --wait-pinokio 240
echo.
if "%USAGE_EXIT_CODE%"=="0" exit /b 0
call :maybe_pause
exit /b %USAGE_EXIT_CODE%
