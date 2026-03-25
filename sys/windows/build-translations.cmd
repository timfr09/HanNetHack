@echo off
REM Build translations for HanNetHack
REM This script should be run as part of the build process to ensure
REM .mo files are always in sync with .po and source code.
REM
REM Usage: sys\windows\build-translations.cmd [--check-only]

setlocal enabledelayedexpansion

set GETTEXT_DIR=lib\gettext\bin
set PO_DIR=po
set LOCALE_DIR=dat\locale\ko\LC_MESSAGES

REM Check if gettext tools are available
if not exist "%GETTEXT_DIR%\msgfmt.exe" (
    echo WARNING: gettext tools not found at %GETTEXT_DIR%
    echo          Run sys\windows\setup-gettext.cmd first.
    exit /b 0
)

if not exist "%PO_DIR%\ko.po" (
    echo WARNING: %PO_DIR%\ko.po not found, skipping translation build.
    exit /b 0
)

echo === Building translations ===

REM Step 1: Re-extract .pot from source (ensures msgids match current code)
echo [1/4] Extracting strings from source...
"%GETTEXT_DIR%\xgettext.exe" --keyword=_ --keyword=N_ --keyword=C_:1c,2 --keyword=P_:1,2 ^
    --from-code=UTF-8 --language=C --no-location ^
    -o "%PO_DIR%\nethack_build.pot" ^
    src\*.c include\*.h win\win32\mswproc.c 2>nul
if errorlevel 1 (
    echo WARNING: xgettext failed, using existing .po file as-is.
    goto :compile_mo
)

REM Step 2: Merge new .pot into ko.po (updates msgid matching)
echo [2/4] Merging translations...
"%GETTEXT_DIR%\msgmerge.exe" --update --backup=none --no-fuzzy-matching ^
    "%PO_DIR%\ko.po" "%PO_DIR%\nethack_build.pot" 2>nul
del "%PO_DIR%\nethack_build.pot" 2>nul

REM Step 3: Check for problems
echo [3/4] Checking translation quality...
set FUZZY_COUNT=0
for /f %%a in ('findstr /c:"#, fuzzy" "%PO_DIR%\ko.po" ^| find /c /v ""') do set FUZZY_COUNT=%%a
if %FUZZY_COUNT% GTR 0 (
    echo WARNING: %FUZZY_COUNT% fuzzy translations found in ko.po
    echo          Review these entries - they may be incorrectly matched.
)

set UNTRANSLATED=0
for /f %%a in ('findstr /c:"msgstr """"" "%PO_DIR%\ko.po" ^| find /c /v ""') do set UNTRANSLATED=%%a
echo       %UNTRANSLATED% untranslated entries.

if "%1"=="--check-only" (
    echo Check complete.
    exit /b 0
)

:compile_mo
REM Step 4: Compile .mo
echo [4/4] Compiling message catalog...
if not exist "%LOCALE_DIR%" mkdir "%LOCALE_DIR%"
"%GETTEXT_DIR%\msgfmt.exe" -o "%LOCALE_DIR%\nethack.mo" "%PO_DIR%\ko.po"
if errorlevel 1 (
    echo ERROR: msgfmt failed to compile ko.po
    exit /b 1
)

echo === Translation build complete ===
endlocal
exit /b 0
