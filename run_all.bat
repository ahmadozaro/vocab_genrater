@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set BACKEND_DIR=%~dp0Back-End
set FRONTEND_DIR=%~dp0Front-End
set FLUTTER_CMD=C:\flutter\flutter\bin\flutter.bat

echo.
echo ===================================
echo    تشغيل مشروع AI-VocabGen
echo ===================================
echo.

REM ─── Check if port 8000 is already in use ─────────────────────────────
netstat -an | find "LISTENING" | find ":8000" >nul 2>&1
if %errorlevel% equ 0 (
    echo [✓] Port 8000 is already in use — Backend is running, skipping startup.
    echo.
) else (
    echo [1/2] Installing Backend dependencies...
    cd /d "%BACKEND_DIR%"

    if not exist ".env" (
        echo [*] Copying .env.example to .env ...
        copy .env.example .env >nul
    )

    echo [*] Running pip install ...
    pip install -r requirements.txt

    echo.
    echo [*] Starting Backend server on http://127.0.0.1:8000 ...
    echo [*] API Docs at http://127.0.0.1:8000/docs
    echo.
    start "AI-VocabGen Backend" cmd /k "cd /d "%BACKEND_DIR%" && python run_backend.py"

    echo [✓] Backend server launched.
    timeout /t 3 /nobreak >nul
)

REM ─── Kill old processes that might lock ports / files ────────────────
echo [*] Cleaning up old processes...
taskkill /f /im flutter.exe 2>nul >nul
taskkill /f /im dart.exe 2>nul >nul
echo [*] Closing Chrome and Edge instances to free port/build locks...
taskkill /f /im chrome.exe 2>nul >nul
taskkill /f /im msedge.exe 2>nul >nul
echo [✓] Old processes terminated.

REM ─── Clean Flutter build artifacts ────────────────────────────────────
echo [2/2] Preparing Frontend...
cd /d "%FRONTEND_DIR%"

if exist "build" (
    echo [*] Removing old build directory...
    takeown /R /F "build" 2>nul >nul
    rmdir /s /q "build" 2>nul >nul
)
if exist ".dart_tool" (
    takeown /R /F ".dart_tool" 2>nul >nul
    rmdir /s /q ".dart_tool" 2>nul >nul
)

echo [*] Running flutter clean ...
call %FLUTTER_CMD% clean

echo [*] Running flutter pub get ...
call %FLUTTER_CMD% pub get

echo.
echo [*] Launching Frontend in Chrome ...
echo 📱 The app will open in a moment...
echo.
echo [*] Running: %FLUTTER_CMD% run -d chrome
echo.

REM ─── Launch Frontend ──────────────────────────────────────────────────
call %FLUTTER_CMD% run -d chrome

echo.
echo [⚠] Flutter has exited. Press any key to close this window.
pause
