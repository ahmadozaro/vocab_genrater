@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo ===================================
echo    تحرير البورت وإعادة تشغيل
echo ===================================
echo.

REM البحث عن العملية التي تستخدم البورت 8000
echo جاري البحث عن العملية على البورت 8000...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000') do (
    echo وجدت العملية برقم %%a
    taskkill /PID %%a /F
    echo تم إيقاف العملية
)

echo.
echo انتظر قليلاً...
timeout /t 3 /nobreak

echo.
echo إعادة تشغيل Backend...
set BACKEND_DIR=%~dp0Back-End
cd /d "%BACKEND_DIR%"
start "AI-VocabGen Backend" cmd /k "python run_backend.py"

echo.
echo ✅ تم تحرير البورت وإعادة تشغيل Backend!
echo تجاهل أي رسائل خطأ أعلاه
echo.

pause
