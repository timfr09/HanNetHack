@echo off
REM HanNetHack Windows Install Script
REM
REM This script copies all necessary files from the build output
REM to a self-contained install directory that can be moved anywhere.
REM
REM Usage: sys\windows\install.cmd [Release|Debug] [x64|Win32|ARM64]
REM   Defaults: Release x64

setlocal enabledelayedexpansion

REM Run from repo root regardless of current directory (%~dp0 = sys\windows\)
pushd "%~dp0..\.." || (
    echo ERROR: Cannot change to repository root.
    exit /b 1
)

set CONFIG=%1
set PLATFORM=%2
if "%CONFIG%"=="" set CONFIG=Release
if "%PLATFORM%"=="" set PLATFORM=x64

set SRCDIR=binary\%CONFIG%\%PLATFORM%
set DSTDIR=install\HanNetHack

echo === HanNetHack Windows Installer ===
echo.
echo Configuration: %CONFIG%
echo Platform:      %PLATFORM%
echo Source:        %SRCDIR%
echo Destination:   %DSTDIR%
echo.

REM Check build output exists
if not exist "%SRCDIR%\NetHack.exe" (
    echo ERROR: %SRCDIR%\NetHack.exe not found.
    echo        Please build the solution first. See sys\windows\build-hannethack.txt
    popd
    exit /b 1
)

REM Create install directory
if not exist "%DSTDIR%" mkdir "%DSTDIR%"

echo [1/2] Copying executables...
copy /y "%SRCDIR%\NetHack.exe" "%DSTDIR%\" >nul
copy /y "%SRCDIR%\NetHackW.exe" "%DSTDIR%\" >nul
copy /y "%SRCDIR%\recover.exe" "%DSTDIR%\" >nul

echo [2/2] Copying game data...
if exist "%SRCDIR%\nhdat370" copy /y "%SRCDIR%\nhdat370" "%DSTDIR%\" >nul
if exist "%SRCDIR%\license" copy /y "%SRCDIR%\license" "%DSTDIR%\" >nul
if exist "%SRCDIR%\Guidebook.txt" copy /y "%SRCDIR%\Guidebook.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\Guidebook.ko.txt" copy /y "%SRCDIR%\Guidebook.ko.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\nethack.txt" copy /y "%SRCDIR%\nethack.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\NetHack.ko.txt" copy /y "%SRCDIR%\NetHack.ko.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\recover.txt" copy /y "%SRCDIR%\recover.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\recover.ko.txt" copy /y "%SRCDIR%\recover.ko.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\opthelp" copy /y "%SRCDIR%\opthelp" "%DSTDIR%\" >nul
if exist "%SRCDIR%\symbols.template" copy /y "%SRCDIR%\symbols.template" "%DSTDIR%\" >nul
if exist "%SRCDIR%\sysconf.template" copy /y "%SRCDIR%\sysconf.template" "%DSTDIR%\" >nul
REM windmain copy_config_content reads template from game dir (DATAPREFIX)
if exist "%SRCDIR%\nethackrc.template" copy /y "%SRCDIR%\nethackrc.template" "%DSTDIR%\" >nul
if exist "%SRCDIR%\record" copy /y "%SRCDIR%\record" "%DSTDIR%\" >nul
if exist "%SRCDIR%\tiles.bmp" copy /y "%SRCDIR%\tiles.bmp" "%DSTDIR%\" >nul

REM Create default config if not present
if not exist "%DSTDIR%\nethackrc" (
    if exist "%SRCDIR%\nethackrc.template" (
        copy /y "%SRCDIR%\nethackrc.template" "%DSTDIR%\nethackrc" >nul
    )
)

REM Create save directory
if not exist "%DSTDIR%\save" mkdir "%DSTDIR%\save"

REM Korean translations + localized help/lua data live inside
REM nhdat now (GNU gettext nethack.mo + plain locale/ko/* text
REM files), so the installer no longer copies libintl/iconv DLLs or
REM a loose locale\ directory.  See src/mo_reader.c for the catalog
REM pipeline.

echo.
echo === Installation Complete ===
echo.
echo Game installed to: %DSTDIR%\
echo.
echo To play:
echo   GUI version:     %DSTDIR%\NetHackW.exe
echo   Console version: %DSTDIR%\NetHack.exe
echo.
echo Note: If NetHack.exe looks frozen or broken, run it from
echo   Command Prompt or Windows Terminal - not from Git Bash.
echo.
echo You can move the %DSTDIR% folder anywhere you like.

popd
endlocal
