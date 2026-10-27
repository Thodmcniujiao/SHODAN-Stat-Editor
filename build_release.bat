@echo off
rem Builds SHODAN Stat Editor Offline from the current source into offline\release\<yyyyMMdd-HHmmss>\,
rem points "SHODAN Stat Editor Offline.lnk" (next to this file) at the new exe, and checks the exe / shortcut chain.
rem   build_release.bat -NoShortcut   builds only
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build_release.ps1" %*
echo.
pause
