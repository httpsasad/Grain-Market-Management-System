@echo off
title Mandi ERP - Grain Market Management System
color 0A

echo =======================================================================
echo          GRAIN MARKET MANAGEMENT SYSTEM (MANDI ERP)
echo =======================================================================
echo.
echo Starting Mandi ERP Server... Please wait...
echo.

:: Change to script directory
cd /d "%~dp0"

:: Open browser automatically after 3 seconds delay
start "" cmd /c "timeout /t 3 >nul && start http://localhost:8000"

:: Run FastAPI Uvicorn Server
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

pause
