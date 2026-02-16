@echo off
setlocal EnableExtensions
color 0A
title OpenClaw Apply OpenAI OAuth

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "CODEX_AUTH=%USERPROFILE%\.codex\auth.json"

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

echo [*] Copying Codex OAuth file into container...
docker exec openclaw sh -lc "mkdir -p /home/node/.codex" >nul 2>&1
docker cp "%CODEX_AUTH%" openclaw:/home/node/.codex/auth.json
if %errorLevel% neq 0 (
    echo ERROR: Failed to copy Codex auth into container.
    pause
    exit /b 1
)

echo [*] Importing OAuth profile into OpenClaw auth store...
docker exec openclaw node -e "const fs=require('fs');const path=require('path');const codex='/home/node/.codex/auth.json';const authStore='/home/node/.openclaw/agents/main/agent/auth-profiles.json';const raw=JSON.parse(fs.readFileSync(codex,'utf8'));const tokens=raw&&raw.tokens?raw.tokens:{};if(!tokens.access_token||!tokens.refresh_token){throw new Error('codex auth.json missing access/refresh token');}let expires=Date.now()+3600_000;try{expires=fs.statSync(codex).mtimeMs+3600_000;}catch{}const dir=path.dirname(authStore);fs.mkdirSync(dir,{recursive:true});let store={version:1,profiles:{},order:{}};if(fs.existsSync(authStore)){try{const prev=JSON.parse(fs.readFileSync(authStore,'utf8'));if(prev&&typeof prev==='object'){store={version:1,profiles:prev.profiles&&typeof prev.profiles==='object'?prev.profiles:{},order:prev.order&&typeof prev.order==='object'?prev.order:{}};}}catch{}}store.profiles['openai-codex:default']={type:'oauth',provider:'openai-codex',access:tokens.access_token,refresh:tokens.refresh_token,expires,...(tokens.account_id?{accountId:tokens.account_id}:{})};store.order['openai-codex']=['openai-codex:default'];fs.writeFileSync(authStore,JSON.stringify(store,null,2));console.log('oauth profile imported');"
if %errorLevel% neq 0 (
    echo ERROR: Failed to import OAuth profile.
    pause
    exit /b 1
)

echo [*] Setting default model to openai-codex/gpt-5.3-codex...
docker exec openclaw node /app/openclaw.mjs models --agent main set openai-codex/gpt-5.3-codex
if %errorLevel% neq 0 (
    echo ERROR: Failed to set default model.
    pause
    exit /b 1
)

echo [*] Verifying model and quick local run...
docker exec openclaw node /app/openclaw.mjs models --agent main status --plain
docker exec openclaw node /app/openclaw.mjs agent --local --to +15555550123 --message "reply only: oauth-ready" --json --timeout 120 >nul 2>&1
if %errorLevel% neq 0 (
    echo WARNING: OAuth profile imported, but test prompt failed.
    echo Check logs: docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env logs -f
    pause
    exit /b 1
)

echo.
echo [OK] OpenAI Codex OAuth applied successfully.
echo Open Control UI: http://127.0.0.1:18789/
echo.
pause
exit /b 0
