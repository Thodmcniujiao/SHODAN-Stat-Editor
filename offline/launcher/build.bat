@echo off
rem Builds "SHODAN Stat Editor Offline.exe" (needs LuaJIT built by buildtools\build_luajit.bat).
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
rem LJ: LuaJIT's src folder (lua.h, lua51.lib), unless set already
if not defined LJ set LJ=%~dp0..\..\..\buildtools\src\LuaJIT\src
cd /d "%~dp0"
rc /nologo /fo launcher.res launcher.rc
cl /nologo /O2 /W3 /MD /I"%LJ%" launcher.c /Fo:launcher.obj /link /SUBSYSTEM:WINDOWS "%LJ%\lua51.lib" user32.lib launcher.res /OUT:"SHODAN Stat Editor Offline.exe"
rem shodan_hash.dll: the hash search (hashsolve.c), the updater's downloads (fetch.c) and installs (update.c)
cl /nologo /O2 /W3 /MT /LD hashsolve.c fetch.c update.c /link winhttp.lib user32.lib /OUT:shodan_hash.dll
call "%~dp0build_steam_bridge.bat"
