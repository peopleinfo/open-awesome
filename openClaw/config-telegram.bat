@echo off
setlocal EnableExtensions
color 0A
title OpenClaw Configure Telegram

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "TELEGRAM_TOKEN="
set "TELEGRAM_ACCOUNT="
set "DRY_RUN="

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--help" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--dry-run" (
    set "DRY_RUN=1"
    shift
    goto parse_args
)
if /I "%~1"=="--token" (
    if "%~2"=="" (
        echo ERROR: --token requires a value.
        goto usage_error
    )
    set "TELEGRAM_TOKEN=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--account" (
    if "%~2"=="" (
        echo ERROR: --account requires a value.
        goto usage_error
    )
    set "TELEGRAM_ACCOUNT=%~2"
    shift
    shift
    goto parse_args
)
if not defined TELEGRAM_TOKEN (
    set "TELEGRAM_TOKEN=%~1"
    shift
    goto parse_args
)
if not defined TELEGRAM_ACCOUNT (
    set "TELEGRAM_ACCOUNT=%~1"
    shift
    goto parse_args
)
echo ERROR: Unknown argument: %~1
goto usage_error

:args_done
echo.
echo ============================================================================
echo OpenClaw Configure Telegram
echo ============================================================================
echo.

if not defined TELEGRAM_TOKEN if defined TELEGRAM_BOT_TOKEN set "TELEGRAM_TOKEN=%TELEGRAM_BOT_TOKEN%"
if not defined TELEGRAM_TOKEN (
    set /p TELEGRAM_TOKEN=Enter Telegram bot token ^(from BotFather^): 
)

if "%TELEGRAM_TOKEN%"=="" (
    echo ERROR: Telegram token is required.
    pause
    exit /b 1
)

set "TOKEN_HAS_COLON=%TELEGRAM_TOKEN::=%"
if "%TOKEN_HAS_COLON%"=="%TELEGRAM_TOKEN%" (
    echo ERROR: Token format looks invalid.
    echo Expected format: 123456789:ABCDEF...
    pause
    exit /b 1
)

if /I "%TELEGRAM_ACCOUNT%"=="default" set "TELEGRAM_ACCOUNT="

if defined DRY_RUN (
    echo [dry-run] Would configure Telegram channel now.
    if defined TELEGRAM_ACCOUNT (
        echo [dry-run] docker exec openclaw node /app/openclaw.mjs channels add --channel telegram --account "%TELEGRAM_ACCOUNT%" --token "******"
    ) else (
        echo [dry-run] docker exec openclaw node /app/openclaw.mjs channels add --channel telegram --token "******"
    )
    echo.
    exit /b 0
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

docker ps --filter "name=openclaw" --filter "status=running" --format "{{.Names}}" | findstr /I /C:"openclaw" >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: OpenClaw container is not running.
    echo Run openClaw\run.bat first.
    pause
    exit /b 1
)

echo [*] Applying Telegram configuration...
if defined TELEGRAM_ACCOUNT (
    docker exec openclaw node /app/openclaw.mjs channels add --channel telegram --account "%TELEGRAM_ACCOUNT%" --token "%TELEGRAM_TOKEN%"
) else (
    docker exec openclaw node /app/openclaw.mjs channels add --channel telegram --token "%TELEGRAM_TOKEN%"
)
if %errorLevel% neq 0 (
    echo [*] channels add unavailable in this build. Applying config fallback...
    docker exec openclaw node /app/openclaw.mjs config set channels.telegram.enabled true --json >nul
    if %errorLevel% neq 0 (
        echo ERROR: Failed to enable channels.telegram.
        pause
        exit /b 1
    )

    if defined TELEGRAM_ACCOUNT (
        docker exec openclaw node /app/openclaw.mjs config set channels.telegram.accounts.%TELEGRAM_ACCOUNT%.enabled true --json >nul
        if %errorLevel% neq 0 (
            echo ERROR: Failed to enable channels.telegram.accounts.%TELEGRAM_ACCOUNT%.
            pause
            exit /b 1
        )

        docker exec openclaw node /app/openclaw.mjs config set channels.telegram.accounts.%TELEGRAM_ACCOUNT%.botToken "%TELEGRAM_TOKEN%" >nul
        if %errorLevel% neq 0 (
            echo ERROR: Failed to set channels.telegram.accounts.%TELEGRAM_ACCOUNT%.botToken.
            pause
            exit /b 1
        )
    ) else (
        docker exec openclaw node /app/openclaw.mjs config set channels.telegram.botToken "%TELEGRAM_TOKEN%" >nul
        if %errorLevel% neq 0 (
            echo ERROR: Failed to set channels.telegram.botToken.
            pause
            exit /b 1
        )
    )

    docker compose -f openClaw/docker-compose.yml --env-file openClaw/.env restart openclaw >nul
    if %errorLevel% neq 0 (
        echo ERROR: Telegram config was written, but failed to restart OpenClaw.
        pause
        exit /b 1
    )
)

docker exec openclaw node /app/openclaw.mjs config set channels.telegram.allowFrom[0] '*' >nul
if %errorLevel% neq 0 (
    echo ERROR: Failed to set channels.telegram.allowFrom to include "*".
    pause
    exit /b 1
)

docker exec openclaw node /app/openclaw.mjs config set channels.telegram.dmPolicy allowlist >nul
if %errorLevel% neq 0 (
    echo ERROR: Failed to set channels.telegram.dmPolicy=allowlist.
    pause
    exit /b 1
)

docker compose -f openClaw/docker-compose.yml --env-file openClaw/.env restart openclaw >nul
if %errorLevel% neq 0 (
    echo ERROR: Telegram channel was configured, but restart failed after access policy update.
    pause
    exit /b 1
)

echo.
echo [*] Channel list:
docker exec openclaw node /app/openclaw.mjs channels list

echo.
echo [*] Channel status probe:
docker exec openclaw node /app/openclaw.mjs channels status --probe

echo.
echo [OK] Telegram channel configured.
echo Next steps:
echo 1. Open Telegram and send /start to your bot.
echo 2. Use the Control UI at http://127.0.0.1:18789 to watch channel events.
echo 3. If probe fails, confirm bot token and network access.
echo.
pause
exit /b 0

:usage
echo Usage:
echo   openClaw\config-telegram.bat [--token TOKEN] [--account ACCOUNT_ID] [--dry-run]
echo.
echo Examples:
echo   openClaw\config-telegram.bat --token 123456:ABCDEF...
echo   openClaw\config-telegram.bat --token 123456:ABCDEF... --account alerts
echo   set TELEGRAM_BOT_TOKEN=123456:ABCDEF... ^&^& openClaw\config-telegram.bat
echo.
exit /b 0

:usage_error
echo.
goto usage
