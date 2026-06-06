@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set FRONTEND_DIR=%~dp0Front-End

echo.
echo ===================================
echo    شغيل Flutter Frontend
echo ===================================
echo.

cd /d "%FRONTEND_DIR%"

echo [1/2] تثبيت المتعلقات...
call flutter pub get

echo.
echo [2/2] بدء تشغيل التطبيق...
echo.
call flutter run

pause
