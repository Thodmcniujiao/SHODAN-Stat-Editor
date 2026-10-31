@echo off
where cl >nul 2>&1
if errorlevel 1 call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
cl /nologo /O2 /W3 /MT /utf-8 /std:c++17 "%~dp0steam_bridge.cpp" /Fo:"%~dp0steam_bridge.obj" /Fe:"%~dp0steam_bridge.exe" /link /SUBSYSTEM:WINDOWS user32.lib shell32.lib crypt32.lib ws2_32.lib
exit /b %errorlevel%
