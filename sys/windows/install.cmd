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
echo        Build output ^(before copy^):
for %%I in ("%SRCDIR%\NetHack.exe") do echo          NetHack.exe   %%~tI  %%~zI bytes
for %%I in ("%SRCDIR%\NetHackW.exe") do echo          NetHackW.exe  %%~tI  %%~zI bytes
for %%A in ("%SRCDIR%\NetHack.exe") do set "NH_T=%%~tA"
for %%B in ("%SRCDIR%\NetHackW.exe") do set "NHW_T=%%~tB"
if not "%NH_T%"=="%NHW_T%" (
    echo.
    echo WARNING: NetHack.exe and NetHackW.exe have different modification times in %SRCDIR%
    echo          This usually means only one project was rebuilt. For matching builds:
    echo          Visual Studio -^> Build -^> Rebuild Solution, or:
    echo          PowerShell: .\Build-HanNetHack.ps1 -Target Rebuild
    echo.
)
copy /y "%SRCDIR%\NetHack.exe" "%DSTDIR%\"
if errorlevel 1 (
    echo ERROR: Could not copy NetHack.exe into install\HanNetHack\
    echo        Close NetHack.exe / NetHackW.exe if they are running from that folder, then retry.
    popd
    exit /b 1
)
copy /y "%SRCDIR%\NetHackW.exe" "%DSTDIR%\"
if errorlevel 1 (
    echo ERROR: Could not copy NetHackW.exe.
    popd
    exit /b 1
)
copy /y "%SRCDIR%\recover.exe" "%DSTDIR%\"
if errorlevel 1 (
    echo ERROR: Could not copy recover.exe.
    popd
    exit /b 1
)
copy /y "sys\windows\NetHack-console.cmd" "%DSTDIR%\" >nul
echo        Installed folder:
for %%I in ("%DSTDIR%\NetHack.exe") do echo          NetHack.exe   %%~tI  %%~zI bytes
for %%I in ("%DSTDIR%\NetHackW.exe") do echo          NetHackW.exe  %%~tI  %%~zI bytes

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
echo   GUI:       double-click %DSTDIR%\NetHackW.exe
echo   Console:   double-click %DSTDIR%\NetHack.exe ^(normal^)
echo   Optional:  %DSTDIR%\NetHack-console.cmd — UTF-8 chcp fallback if console text garbles
echo.
echo Note: Git Bash often breaks the console build; use cmd / Windows Terminal if stuck.
echo Old nethackrc may still request IBMGraphics: delete %DSTDIR%\nethackrc once to take new defaults,
echo   or edit OPTIONS symset to Enhanced1 ^(see nethackrc.template^).
echo.
echo You can move the %DSTDIR% folder anywhere you like.

popd
endlocal
