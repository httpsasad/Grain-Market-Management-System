@echo off
title Mandi ERP - Create Desktop Shortcut
color 0E

echo Creating Mandi ERP Desktop Shortcut... Please wait...
echo.

set SCRIPT="%TEMP%\%RANDOM%-%RANDOM%-%RANDOM%-%RANDOM%.vbs"

echo Set oWS = WScript.CreateObject("WScript.Shell") >> %SCRIPT%
echo sLinkFile = oWS.SpecialFolders("Desktop") ^& "\Mandi ERP.lnk" >> %SCRIPT%
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> %SCRIPT%
echo oLink.TargetPath = "%~dp0Start_Mandi_ERP.bat" >> %SCRIPT%
echo oLink.WorkingDirectory = "%~dp0" >> %SCRIPT%
echo oLink.Description = "Mandi ERP - Grain Market Management System" >> %SCRIPT%
echo oLink.Save >> %SCRIPT%

cscript /nologo %SCRIPT%
del %SCRIPT%

echo =======================================================================
echo Desktop Shortcut "Mandi ERP" created successfully on Desktop!
echo =======================================================================
echo.
pause
