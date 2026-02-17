@echo off
setlocal EnableExtensions
title Zero Claw Starter

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

where node >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is required. Install Node.js 20+ and retry.
    exit /b 1
)

where npm >nul 2>&1
if errorlevel 1 (
    echo ERROR: npm is required. Install npm and retry.
    exit /b 1
)

pushd "%SCRIPT_DIR%"

if not exist ".env" (
    if exist ".env.example" (
        copy /Y ".env.example" ".env" >nul
        echo [*] Created .env from .env.example
    )
)

if not exist "node_modules" (
    echo [*] Installing dependencies...
    call npm install
    if errorlevel 1 (
        popd
        echo ERROR: npm install failed.
        exit /b 1
    )
)

if not defined ZERO_CLAW_API_HOST set "ZERO_CLAW_API_HOST=127.0.0.1"
if not defined ZERO_CLAW_API_PORT set "ZERO_CLAW_API_PORT=3010"
if not defined ZERO_CLAW_API_URL set "ZERO_CLAW_API_URL=http://127.0.0.1:3010"

echo [*] Starting API + Electron dashboard...
call npm run dev
set "EXIT_CODE=%errorlevel%"
popd
exit /b %EXIT_CODE%
