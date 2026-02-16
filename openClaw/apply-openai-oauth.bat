@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 0A
title OpenClaw Apply OpenAI OAuth

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CODEX_AUTH=%USERPROFILE%\.codex\auth.json"
set "MAX_RETRIES=1"
set "SKIP_PROBE="
set "RETRY_COUNT=0"
set "LOG_WINDOW_SECONDS=180"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--max-retries" (
    if "%~2"=="" (
        echo ERROR: --max-retries requires a non-negative integer value.
        pause
        exit /b 1
    )
    set "MAX_RETRIES=%~2"
    shift
    shift
    goto parse_args
)
if /I "%~1"=="--skip-probe" (
    set "SKIP_PROBE=1"
    shift
    goto parse_args
)
if /I "%~1"=="--help" goto usage
if /I "%~1"=="-h" goto usage
echo ERROR: Unknown argument: %~1
goto usage_error

:args_done
echo(%MAX_RETRIES%| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo ERROR: --max-retries must be a non-negative integer.
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo OpenClaw Apply OpenAI Codex OAuth
echo ============================================================================
echo.

if not exist "%CODEX_AUTH%" (
    echo ERROR: Codex auth file not found: %CODEX_AUTH%
    echo Please login first with Codex CLI on host.
    echo Example: codex login
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

set "OPENCLAW_RUNNING="
for /f "usebackq delims=" %%N in (`docker ps --filter "name=^/openclaw$" --filter "status=running" --format "{{.Names}}"`) do (
    if /I "%%N"=="openclaw" set "OPENCLAW_RUNNING=1"
)
if not defined OPENCLAW_RUNNING (
    echo ERROR: OpenClaw container is not running.
    echo Run openClaw\run.bat first.
    pause
    exit /b 1
)

:apply_and_probe
call :apply_profile
if errorlevel 1 (
    pause
    exit /b 1
)

if defined SKIP_PROBE goto success

echo [*] Verifying model and quick local run...
docker exec openclaw node /app/openclaw.mjs models --agent main status --plain
docker exec openclaw node /app/openclaw.mjs agent --local --to +15555550123 --message "reply only: oauth-ready" --json --timeout 120 >nul 2>&1
if %errorLevel% equ 0 goto success

call :is_refresh_failure
if errorlevel 1 (
    echo WARNING: OAuth profile imported, but test prompt failed.
    echo Check logs: docker logs --tail 200 openclaw
    pause
    exit /b 1
)

if !RETRY_COUNT! geq %MAX_RETRIES% (
    echo ERROR: OAuth refresh failure persisted after %MAX_RETRIES% retry attempt^(s^).
    echo Re-authenticate on host and re-apply:
    echo   codex login
    echo   openClaw\apply-openai-oauth.bat
    echo Logs: docker logs --tail 200 openclaw
    pause
    exit /b 1
)

set /a RETRY_COUNT+=1
echo [*] Detected openai-codex OAuth refresh failure. Retrying import ^(!RETRY_COUNT!/%MAX_RETRIES%^)^...
timeout /t 3 /nobreak >nul
goto apply_and_probe

:success
echo.
if !RETRY_COUNT! gtr 0 (
    echo [OK] OpenAI Codex OAuth applied successfully after !RETRY_COUNT! retry attempt^(s^).
) else (
    echo [OK] OpenAI Codex OAuth applied successfully.
)
echo Open Control UI: http://127.0.0.1:18789/
echo.
pause
exit /b 0

:apply_profile
echo [*] Copying Codex OAuth file into container...
docker exec openclaw sh -lc "mkdir -p /home/node/.codex" >nul 2>&1
docker cp "%CODEX_AUTH%" openclaw:/home/node/.codex/auth.json
if %errorLevel% neq 0 (
    echo ERROR: Failed to copy Codex auth into container.
    exit /b 1
)

echo [*] Importing OAuth profile into OpenClaw auth store...
docker exec openclaw node -e "const fs=require('fs');const path=require('path');const codex='/home/node/.codex/auth.json';const authStore='/home/node/.openclaw/agents/main/agent/auth-profiles.json';const raw=JSON.parse(fs.readFileSync(codex,'utf8'));const tokens=raw&&raw.tokens?raw.tokens:{};if(tokens.access_token&&tokens.refresh_token){}else{throw new Error('codex auth.json missing access/refresh token');}let expires=Date.now()+48*3600_000;try{const payload=JSON.parse(Buffer.from(String(tokens.access_token).split('.')[1]||'','base64url').toString('utf8'));if(typeof payload.exp==='number'&&Number.isFinite(payload.exp)){expires=payload.exp*1000;}}catch{}const dir=path.dirname(authStore);fs.mkdirSync(dir,{recursive:true});let store={version:1,profiles:{},order:{}};if(fs.existsSync(authStore)){try{const prev=JSON.parse(fs.readFileSync(authStore,'utf8'));if(prev&&typeof prev==='object'){store={version:1,profiles:prev.profiles&&typeof prev.profiles==='object'?prev.profiles:{},order:prev.order&&typeof prev.order==='object'?prev.order:{}};}}catch{}}store.profiles['openai-codex:default']={type:'oauth',provider:'openai-codex',access:tokens.access_token,refresh:tokens.refresh_token,expires,...(tokens.account_id?{accountId:tokens.account_id}:{})};store.order['openai-codex']=['openai-codex:default'];fs.writeFileSync(authStore,JSON.stringify(store,null,2));console.log('oauth profile imported',new Date(expires).toISOString());"
if %errorLevel% neq 0 (
    echo ERROR: Failed to import OAuth profile.
    exit /b 1
)

echo [*] Setting default model to openai-codex/gpt-5.3-codex...
docker exec openclaw node /app/openclaw.mjs models --agent main set openai-codex/gpt-5.3-codex
if %errorLevel% neq 0 (
    echo ERROR: Failed to set default model.
    exit /b 1
)
exit /b 0

:is_refresh_failure
docker logs --since %LOG_WINDOW_SECONDS%s openclaw 2>&1 | findstr /I /C:"OAuth token refresh failed for openai-codex" /C:"refresh_token_reused" >nul
if errorlevel 1 exit /b 1
exit /b 0

:usage
echo Usage:
echo   openClaw\apply-openai-oauth.bat [--max-retries N] [--skip-probe]
echo.
echo Options:
echo   --max-retries N  Number of automatic retries after refresh failure ^(default: 1^)
echo   --skip-probe     Skip the quick local test prompt
echo.
exit /b 0

:usage_error
echo.
call :usage >nul
exit /b 1
