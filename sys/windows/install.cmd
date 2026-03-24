@echo off
REM HanNetHack Windows Install Script
REM
REM This script copies all necessary files from the build output
REM to a self-contained install directory that can be moved anywhere.
REM
REM Usage: sys\windows\install.cmd [Release|Debug] [x64|Win32|ARM64]
REM   Defaults: Release x64

setlocal enabledelayedexpansion

set CONFIG=%1
set PLATFORM=%2
if "%CONFIG%"=="" set CONFIG=Release
if "%PLATFORM%"=="" set PLATFORM=x64

set SRCDIR=binary\%CONFIG%\%PLATFORM%
set DSTDIR=install\HanNetHack
set GETTEXTBIN=lib\gettext\bin

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
    goto :eof
)

REM Create install directory
if not exist "%DSTDIR%" mkdir "%DSTDIR%"

echo [1/4] Copying executables...
copy /y "%SRCDIR%\NetHack.exe" "%DSTDIR%\" >nul
copy /y "%SRCDIR%\NetHackW.exe" "%DSTDIR%\" >nul
copy /y "%SRCDIR%\recover.exe" "%DSTDIR%\" >nul

echo [2/4] Copying game data...
if exist "%SRCDIR%\nhdat370" copy /y "%SRCDIR%\nhdat370" "%DSTDIR%\" >nul
if exist "%SRCDIR%\license" copy /y "%SRCDIR%\license" "%DSTDIR%\" >nul
if exist "%SRCDIR%\Guidebook.txt" copy /y "%SRCDIR%\Guidebook.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\nethack.txt" copy /y "%SRCDIR%\nethack.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\recover.txt" copy /y "%SRCDIR%\recover.txt" "%DSTDIR%\" >nul
if exist "%SRCDIR%\opthelp" copy /y "%SRCDIR%\opthelp" "%DSTDIR%\" >nul
if exist "%SRCDIR%\symbols.template" copy /y "%SRCDIR%\symbols.template" "%DSTDIR%\" >nul
if exist "%SRCDIR%\sysconf.template" copy /y "%SRCDIR%\sysconf.template" "%DSTDIR%\" >nul
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

echo [3/4] Copying runtime DLLs...
if exist "%GETTEXTBIN%\libintl-8.dll" (
    copy /y "%GETTEXTBIN%\libintl-8.dll" "%DSTDIR%\" >nul
    copy /y "%GETTEXTBIN%\libiconv-2.dll" "%DSTDIR%\" >nul
    copy /y "%GETTEXTBIN%\libgcc_s_seh-1.dll" "%DSTDIR%\" >nul
    copy /y "%GETTEXTBIN%\libwinpthread-1.dll" "%DSTDIR%\" >nul
) else if exist "%SRCDIR%\libintl-8.dll" (
    copy /y "%SRCDIR%\libintl-8.dll" "%DSTDIR%\" >nul
    copy /y "%SRCDIR%\libiconv-2.dll" "%DSTDIR%\" >nul
    copy /y "%SRCDIR%\libgcc_s_seh-1.dll" "%DSTDIR%\" >nul
    copy /y "%SRCDIR%\libwinpthread-1.dll" "%DSTDIR%\" >nul
) else (
    echo WARNING: gettext DLLs not found. Korean localization may not work.
    echo          Run sys\windows\setup-gettext.cmd first.
)

echo [4/4] Copying locale data...
REM Compile .mo from .po if msgfmt is available and .mo doesn't exist
if not exist "dat\locale\ko\LC_MESSAGES\nethack.mo" (
    if exist "lib\gettext\bin\msgfmt.exe" (
        if exist "po\ko.po" (
            echo       Compiling Korean translation...
            if not exist "dat\locale\ko\LC_MESSAGES" mkdir "dat\locale\ko\LC_MESSAGES"
            "lib\gettext\bin\msgfmt.exe" -o "dat\locale\ko\LC_MESSAGES\nethack.mo" "po\ko.po"
        )
    )
)
REM Copy .mo translation files
if exist "dat\locale\ko\LC_MESSAGES\nethack.mo" (
    if not exist "%DSTDIR%\locale\ko\LC_MESSAGES" mkdir "%DSTDIR%\locale\ko\LC_MESSAGES"
    copy /y "dat\locale\ko\LC_MESSAGES\nethack.mo" "%DSTDIR%\locale\ko\LC_MESSAGES\nethack.mo" >nul
) else if exist "po\ko.mo" (
    if not exist "%DSTDIR%\locale\ko\LC_MESSAGES" mkdir "%DSTDIR%\locale\ko\LC_MESSAGES"
    copy /y "po\ko.mo" "%DSTDIR%\locale\ko\LC_MESSAGES\nethack.mo" >nul
) else (
    echo WARNING: Korean translation file not found. Run msgfmt or check po/ko.po
)

echo.
echo === Installation Complete ===
echo.
echo Game installed to: %DSTDIR%\
echo.
echo To play:
echo   GUI version:     %DSTDIR%\NetHackW.exe
echo   Console version: %DSTDIR%\NetHack.exe
echo.
echo You can move the %DSTDIR% folder anywhere you like.

endlocal
