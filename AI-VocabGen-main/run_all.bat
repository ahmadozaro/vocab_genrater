@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set BACKEND_DIR=%~dp0Back-End
set FRONTEND_DIR=%~dp0Front-End

echo.
echo ===================================
echo    شغيل مشروع AI-VocabGen
echo ===================================
echo.

REM تشغيل Backend
echo [1/2] جاري تثبيت متعلقات Backend...
cd /d "%BACKEND_DIR%"

if not exist ".env" (
    echo [تم] انسخ .env.example إلى .env
    copy .env.example .env
)

echo [تم] تثبيت المتعلقات...
pip install -r requirements.txt

echo.
echo [تم] بدء تشغيل Backend...
echo 📍 Server سيعمل على: http://127.0.0.1:8000
echo 📍 API Docs على: http://127.0.0.1:8000/docs
echo.
start "AI-VocabGen Backend" cmd /k "cd /d "%BACKEND_DIR%" && python run_backend.py"

REM انتظر قليل
timeout /t 5 /nobreak

REM تشغيل Frontend
echo.
echo [2/2] جاري تثبيت متعلقات Frontend...
cd /d "%FRONTEND_DIR%"

echo [تم] تثبيت المتعلقات...
call flutter pub get

echo.
echo [تم] بدء تشغيل Frontend...
echo 📱 سيفتح التطبيق في لحظات...
echo.

call flutter run

pause
