@echo off
REM HanNetHack — optional helper: cd here + chcp 65001 then NetHack.exe.
REM Default play is double-click NetHack.exe; use this only if UTF-8 still garbles.

cd /d "%~dp0"
chcp 65001 >nul 2>&1
NetHack.exe %*
set NH_EC=%ERRORLEVEL%
if %NH_EC% neq 0 (
    echo.
    echo NetHack exited with code %NH_EC%.
    pause
)
exit /b %NH_EC%
