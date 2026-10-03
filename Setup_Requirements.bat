@echo off
title Mandi ERP - One Time Setup
color 0B

echo =======================================================================
echo          ONE-TIME DEPENDENCY SETUP FOR MANDI ERP
echo =======================================================================
echo.
echo Installing required Python packages... Please wait...
echo.

cd /d "%~dp0"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo.
echo =======================================================================
echo Setup Completed Successfully! You can now run Start_Mandi_ERP.bat
echo =======================================================================
echo.
pause
