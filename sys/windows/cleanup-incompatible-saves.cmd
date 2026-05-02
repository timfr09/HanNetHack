@echo off
REM Delete saves/bones/levels that no longer match the current executable.
REM Windows 3.7+ stores saves in LOCALAPPDATA\NetHack\<major>.<minor>\ NOT in
REM Users\...\NetHack\save\ — old cleanup paths missed them.
REM Does NOT remove sysconf/record in ProgramData (only bones bon*).

setlocal
echo.
echo HanNetHack: incompatible save data cleanup
echo.
echo Removes:
echo   - LOCALAPPDATA\NetHack\3.7\*  (saves, levels, locks — full wipe of that folder's files^)
echo   - PROGRAMDATA\NetHack\3.7\bon*  (bones^)
echo   - Legacy %%USERPROFILE%%\nethack\...\save and bon*
echo   - Portable: repo install\HanNetHack\*.NetHack-saved-game, bon*, save\*
echo.

REM -------- Modern Windows layout (NetHack 3.7+) --------
set "NHUSER=%LOCALAPPDATA%\NetHack\3.7"
if exist "%NHUSER%" (
    echo [Clear] %NHUSER%\*.*
    del /q "%NHUSER%\*.*" 2>nul
    echo      done.
) else (
    echo (skip) %NHUSER%
)

REM 3.6 saves if present (same issue after upgrades)
set "NHUSER36=%LOCALAPPDATA%\NetHack\3.6"
if exist "%NHUSER36%" (
    echo [Clear] %NHUSER36%\*.*
    del /q "%NHUSER36%\*.*" 2>nul
)

REM Bones (shared)
set "NHGLOBAL=%PROGRAMDATA%\NetHack\3.7"
if exist "%NHGLOBAL%\bon*" (
    echo [Del bones] %NHGLOBAL%\bon*
    del /q "%NHGLOBAL%\bon*" 2>nul
) else (
    echo (none) %NHGLOBAL%\bon*
)

set "NHGLOBAL36=%PROGRAMDATA%\NetHack\3.6"
if exist "%NHGLOBAL36%\bon*" (
    del /q "%NHGLOBAL36%\bon*" 2>nul
)

REM -------- Legacy profile tree (pre-Known Folder paths) --------
set "PG=%USERPROFILE%\nethack"
if exist "%PG%\save\*.*" (
    echo [Clear] %PG%\save\*
    del /q "%PG%\save\*.*" 2>nul
)
if exist "%PG%\bon*" del /q "%PG%\bon*" 2>nul
for %%V in (3.7 3.6) do (
    if exist "%PG%\%%V\save\*.*" del /q "%PG%\%%V\save\*.*" 2>nul
    if exist "%PG%\%%V\bon*" del /q "%PG%\%%V\bon*" 2>nul
)

REM -------- Portable / repo install (exe directory may hold *.NetHack-saved-game) --------
pushd "%~dp0..\.." 2>nul
if exist "install\HanNetHack\*.NetHack-saved-game" (
    echo [Del] install\HanNetHack\*.NetHack-saved-game
    del /q "install\HanNetHack\*.NetHack-saved-game" 2>nul
)
if exist "install\HanNetHack\save\*.*" del /q "install\HanNetHack\save\*.*" 2>nul
if exist "install\HanNetHack\bon*" del /q "install\HanNetHack\bon*" 2>nul
for %%D in ("binary\Release\x64" "binary\Debug\x64") do (
    if exist %%~D\*.NetHack-saved-game del /q %%~D\*.NetHack-saved-game 2>nul
    if exist %%~D\bon* del /q %%~D\bon* 2>nul
)
popd 2>nul

echo.
echo Done. Start NetHack and choose a new game.
pause
