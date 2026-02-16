@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 0A
title OpenClaw Pinokio Host Helper

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=start"

set "PINOKIO_LOG=/home/node/.openclaw/logs/pinokio-web.log"
set "PINOKIO_RUNNER=/home/node/.openclaw/workspace/run-pinokio-web.sh"
set "PINOKIO_HOME_LINUX=/pinokio-data"

if /I "%ACTION%"=="--help" goto usage
if /I "%ACTION%"=="-h" goto usage

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

if /I "%ACTION%"=="start" goto start_pinokio
if /I "%ACTION%"=="stop" goto stop_pinokio
if /I "%ACTION%"=="status" goto status_pinokio
if /I "%ACTION%"=="logs" goto logs_pinokio

echo ERROR: Unknown action "%ACTION%".
goto usage_error

:check_port_mapping
docker port openclaw 42000/tcp >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Host port forwarding for 42000 is missing.
    echo Expected docker mapping for 42000/tcp on container "openclaw".
    echo Recreate OpenClaw container after updating compose:
    echo   docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env up -d openclaw
    exit /b 1
)
exit /b 0

:is_pinokio_running
docker exec openclaw pgrep -f "node script/index" >nul 2>&1
exit /b %errorLevel%

:probe_pinokio
docker exec openclaw curl -fsS --max-time 2 http://127.0.0.1:42000/ >nul 2>&1
exit /b %errorLevel%

:normalize_pinokio_home
docker exec openclaw node -e "const fs=require('fs');const path=require('path');const targets=['/home/node/.openclaw/workspace/pinokio-forked/script/pinokio.json','/home/node/.pinokio/config.json'];for(const p of targets){let cfg={};try{cfg=JSON.parse(fs.readFileSync(p,'utf8'));}catch{}cfg.home='%PINOKIO_HOME_LINUX%';if(!cfg.theme)cfg.theme='light';if(!Object.prototype.hasOwnProperty.call(cfg,'HTTP_PROXY'))cfg.HTTP_PROXY='';if(!Object.prototype.hasOwnProperty.call(cfg,'HTTPS_PROXY'))cfg.HTTPS_PROXY='';if(!Object.prototype.hasOwnProperty.call(cfg,'NO_PROXY'))cfg.NO_PROXY='';fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,JSON.stringify(cfg,null,2));console.log('pinokio home set',p,'=>',cfg.home);}"
exit /b %errorLevel%

:ensure_pinokio_home_writable
docker exec --user root openclaw sh -lc "mkdir -p '%PINOKIO_HOME_LINUX%' && chown -R node:node '%PINOKIO_HOME_LINUX%'" >nul 2>&1
if %errorLevel% neq 0 (
    echo WARNING: Could not pre-fix ownership for %PINOKIO_HOME_LINUX%.
    echo Pinokio may fail with EACCES if this path is not writable by user "node".
)
exit /b 0

:start_pinokio
call :check_port_mapping
if errorlevel 1 (
    pause
    exit /b 1
)

call :is_pinokio_running
if not errorlevel 1 (
    echo [*] Pinokio is already running.
    goto status_pinokio
)

echo [*] Normalizing Pinokio home path for container runtime...
call :normalize_pinokio_home
if errorlevel 1 (
    echo ERROR: Failed to normalize Pinokio home path.
    pause
    exit /b 1
)

echo [*] Ensuring Pinokio home path is writable...
call :ensure_pinokio_home_writable

echo [*] Starting Pinokio web service inside OpenClaw container...
docker exec openclaw node -e "const fs=require('fs');const cp=require('child_process');fs.mkdirSync('/home/node/.openclaw/logs',{recursive:true});const out=fs.openSync('%PINOKIO_LOG%','a');const env={...process.env,PINOKIO_HOME:'%PINOKIO_HOME_LINUX%'};const child=cp.spawn('bash',['%PINOKIO_RUNNER%'],{detached:true,stdio:['ignore',out,out],env});child.unref();console.log('started pinokio pid',child.pid,'home',env.PINOKIO_HOME);"
if %errorLevel% neq 0 (
    echo ERROR: Failed to start Pinokio process.
    pause
    exit /b 1
)

echo.
echo [OK] Pinokio launch requested.
echo It can take 30-90 seconds on first run.
echo Host URL: http://localhost:42000
echo Check readiness: openClaw\pinokio-host.bat status
echo.
pause
exit /b 0

:stop_pinokio
call :is_pinokio_running
if errorlevel 1 (
    echo [*] Pinokio is not running.
    pause
    exit /b 0
)

echo [*] Stopping Pinokio web service...
docker exec openclaw pkill -f "node script/index" >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: Failed to stop Pinokio process.
    pause
    exit /b 1
)

echo [OK] Pinokio stopped.
pause
exit /b 0

:status_pinokio
call :check_port_mapping
if errorlevel 1 (
    pause
    exit /b 1
)

call :is_pinokio_running
if errorlevel 1 (
    echo Pinokio process: stopped
    echo Host URL: http://localhost:42000
    pause
    exit /b 1
)

call :probe_pinokio
if errorlevel 1 (
    echo Pinokio process: running
    echo HTTP probe: not ready yet
    echo Check logs: openClaw\pinokio-host.bat logs
    pause
    exit /b 1
)

echo Pinokio process: running
echo HTTP probe: healthy
echo Host URL: http://localhost:42000
pause
exit /b 0

:logs_pinokio
echo [*] Streaming Pinokio log from container (Ctrl+C to stop)...
docker exec openclaw sh -lc "if [ -f \"%PINOKIO_LOG%\" ]; then tail -n 200 -f \"%PINOKIO_LOG%\"; else echo 'No pinokio log file yet.'; fi"
exit /b %errorLevel%

:usage
echo Usage:
echo   openClaw\pinokio-host.bat [start^|stop^|status^|logs]
echo.
echo Default action is "start".
echo Host URL: http://localhost:42000
echo.
exit /b 0

:usage_error
echo.
call :usage >nul
exit /b 1
