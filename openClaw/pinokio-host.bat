@echo off
setlocal EnableExtensions EnableDelayedExpansion
color 0A
title OpenClaw Pinokio Host Helper

set "ACTION="
set "NO_PAUSE=0"
set "WAIT_READY_SECONDS=0"

set "PINOKIO_LOG=/home/node/.openclaw/logs/pinokio-web.log"
set "PINOKIO_RUNNER=/home/node/.openclaw/workspace/run-pinokio-web.sh"
set "PINOKIO_HOME_LINUX=/pinokio-data"

:parse_args
if "%~1"=="" goto parse_done
if /I "%~1"=="--help" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--no-pause" (
    set "NO_PAUSE=1"
    shift
    goto parse_args
)
if /I "%~1"=="--wait-ready" goto parse_wait_ready
if not defined ACTION (
    set "ACTION=%~1"
    shift
    goto parse_args
)
echo ERROR: Unknown argument "%~1".
goto usage_error

:parse_wait_ready
shift
if "%~1"=="" (
    echo ERROR: --wait-ready requires a seconds value.
    goto usage_error
)
set "WAIT_READY_SECONDS=%~1"
echo(!WAIT_READY_SECONDS!| findstr /r /c:"^[1-9][0-9]*$" >nul
if errorlevel 1 (
    echo ERROR: --wait-ready must be a positive integer. Got [!WAIT_READY_SECONDS!].
    goto usage_error
)
shift
goto parse_args

:parse_done
if not defined ACTION set "ACTION=start"

docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not installed or not in PATH.
    goto fail
)

docker info >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker daemon is not running.
    echo Start Docker Desktop and retry.
    goto fail
)

set "OPENCLAW_RUNNING="
for /f "usebackq delims=" %%N in (`docker ps --filter "name=^/openclaw$" --filter "status=running" --format "{{.Names}}"`) do (
    if /I "%%N"=="openclaw" set "OPENCLAW_RUNNING=1"
)
if not defined OPENCLAW_RUNNING (
    echo ERROR: OpenClaw container is not running.
    echo Run openClaw\run.bat first.
    goto fail
)

if /I "%ACTION%"=="start" goto action_start
if /I "%ACTION%"=="stop" goto action_stop
if /I "%ACTION%"=="status" goto action_status
if /I "%ACTION%"=="logs" goto action_logs

echo ERROR: Unknown action "%ACTION%".
goto usage_error

:check_required_ports
docker port openclaw 42000/tcp >nul 2>&1
if errorlevel 1 (
    echo ERROR: Host port forwarding for 42000 is missing.
    echo Recreate container:
    echo   docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env up -d openclaw
    goto fail
)
docker port openclaw 30001/tcp >nul 2>&1
if errorlevel 1 (
    echo ERROR: Host port forwarding for 30001 is missing.
    echo Recreate container:
    echo   docker compose -f openClaw\docker-compose.yml --env-file openClaw\.env up -d openclaw
    goto fail
)
goto :eof

:action_start
call :check_required_ports
if errorlevel 1 goto fail

docker exec openclaw pgrep -f "node script/index" >nul 2>&1
if not errorlevel 1 goto start_already_running

echo [*] Normalizing Pinokio home path for container runtime...
docker exec openclaw node -e "const fs=require('fs');const path=require('path');const targets=['/home/node/.openclaw/workspace/pinokio-forked/script/pinokio.json','/home/node/.pinokio/config.json'];for(const p of targets){let cfg={};try{cfg=JSON.parse(fs.readFileSync(p,'utf8'));}catch{}cfg.home='%PINOKIO_HOME_LINUX%';if(!cfg.theme)cfg.theme='light';if(!Object.prototype.hasOwnProperty.call(cfg,'HTTP_PROXY'))cfg.HTTP_PROXY='';if(!Object.prototype.hasOwnProperty.call(cfg,'HTTPS_PROXY'))cfg.HTTPS_PROXY='';if(!Object.prototype.hasOwnProperty.call(cfg,'NO_PROXY'))cfg.NO_PROXY='';fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,JSON.stringify(cfg,null,2));console.log('pinokio home set',p,'=>',cfg.home);}"
if errorlevel 1 (
    echo ERROR: Failed to normalize Pinokio home path.
    goto fail
)

echo [*] Ensuring Pinokio home path is writable...
docker exec --user root openclaw sh -lc "mkdir -p '%PINOKIO_HOME_LINUX%' && chown -R node:node '%PINOKIO_HOME_LINUX%'" >nul 2>&1
if errorlevel 1 (
    echo WARNING: Could not pre-fix ownership for %PINOKIO_HOME_LINUX%.
)

echo [*] Starting Pinokio web service inside OpenClaw container...
docker exec openclaw node -e "const fs=require('fs');const cp=require('child_process');fs.mkdirSync('/home/node/.openclaw/logs',{recursive:true});const out=fs.openSync('%PINOKIO_LOG%','a');const env={...process.env,PINOKIO_HOME:'%PINOKIO_HOME_LINUX%'};const child=cp.spawn('bash',['%PINOKIO_RUNNER%'],{detached:true,stdio:['ignore',out,out],env});child.unref();console.log('started pinokio pid',child.pid,'home',env.PINOKIO_HOME);"
if errorlevel 1 (
    echo ERROR: Failed to start Pinokio process.
    goto fail
)

goto maybe_wait_ready

:start_already_running
echo [*] Pinokio is already running.

:maybe_wait_ready
if %WAIT_READY_SECONDS% leq 0 goto action_start_done
echo [*] Waiting for Pinokio HTTP readiness on http://localhost:42000 ...
set /a WAITED=0

:start_wait_loop
docker exec openclaw curl -fsS --max-time 2 http://127.0.0.1:42000/ >nul 2>&1
if not errorlevel 1 goto start_wait_ok
if !WAITED! geq %WAIT_READY_SECONDS% goto start_wait_timeout
powershell -NoProfile -Command "Start-Sleep -Seconds 3" >nul 2>&1
set /a WAITED+=3
goto start_wait_loop

:start_wait_ok
echo [OK] Pinokio is ready.
goto action_start_done

:start_wait_timeout
echo ERROR: Pinokio did not become ready within %WAIT_READY_SECONDS%s.
echo Check logs: openClaw\pinokio-host.bat logs
goto fail

:action_start_done
echo.
echo [OK] Pinokio launch requested.
echo Host URL: http://localhost:42000
if "%NO_PAUSE%"=="0" pause
exit /b 0

:action_stop
docker exec openclaw pgrep -f "node script/index" >nul 2>&1
if errorlevel 1 (
    echo [*] Pinokio is not running.
    if "%NO_PAUSE%"=="0" pause
    exit /b 0
)

echo [*] Stopping Pinokio web service...
docker exec openclaw pkill -f "node script/index" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Failed to stop Pinokio process.
    goto fail
)

echo [OK] Pinokio stopped.
if "%NO_PAUSE%"=="0" pause
exit /b 0

:action_status
call :check_required_ports
if errorlevel 1 goto fail

docker exec openclaw pgrep -f "node script/index" >nul 2>&1
if errorlevel 1 (
    echo Pinokio process: stopped
    echo Host URL: http://localhost:42000
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

docker exec openclaw curl -fsS --max-time 2 http://127.0.0.1:42000/ >nul 2>&1
if errorlevel 1 (
    echo Pinokio process: running
    echo HTTP probe: not ready yet
    echo Check logs: openClaw\pinokio-host.bat logs
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

echo Pinokio process: running
echo HTTP probe: healthy
echo Host URL: http://localhost:42000
if "%NO_PAUSE%"=="0" pause
exit /b 0

:action_logs
echo [*] Streaming Pinokio log from container (Ctrl+C to stop)...
docker exec openclaw sh -lc "if [ -f \"%PINOKIO_LOG%\" ]; then tail -n 200 -f \"%PINOKIO_LOG%\"; else echo 'No pinokio log file yet.'; fi"
exit /b %errorLevel%

:usage
if not defined USAGE_EXIT_CODE set "USAGE_EXIT_CODE=0"
echo Usage:
echo   openClaw\pinokio-host.bat [start^|stop^|status^|logs] [--wait-ready SECONDS] [--no-pause]
echo.
echo Default action is "start".
echo --wait-ready SECONDS waits for HTTP readiness on 42000 before returning.
echo --no-pause disables pause prompts for unattended startup tasks.
echo Host URL: http://localhost:42000
echo.
if "%USAGE_EXIT_CODE%"=="1" exit /b 1
exit /b 0

:usage_error
echo.
set "USAGE_EXIT_CODE=1"
goto usage

:fail
if "%NO_PAUSE%"=="0" pause
exit /b 1
