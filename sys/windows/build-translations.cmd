@echo off
REM Build translations for HanNetHack
REM This script should be run as part of the build process to ensure
REM .mo files are always in sync with .po and source code.
REM
REM Usage: sys\windows\build-translations.cmd [--check-only]

setlocal enabledelayedexpansion

set GETTEXT_DIR=lib\gettext\bin
set PO_DIR=po
set LOCALE_DIR=dat\locale\ko

REM Check if gettext tools are available
if not exist "%GETTEXT_DIR%\msgfmt.exe" (
    echo WARNING: gettext tools not found at %GETTEXT_DIR%
    echo          Run sys\windows\setup-gettext.cmd to download msgfmt/msgcat.
    exit /b 0
)

if not exist "%PO_DIR%\ko_manual.po" (
    if not exist "%PO_DIR%\ko.po" (
        echo WARNING: neither ko_manual.po nor ko.po found in %PO_DIR%, skipping.
        exit /b 0
    )
)

echo === Building translations ===

REM Step 1 (optional): Re-extract .pot and refresh ko.po so fuzzy/untranslated
REM stats reflect the current source.  ko.po is a gitignored local cache; if
REM xgettext is missing we just keep whatever local ko.po already exists and
REM move on.
if exist "%PO_DIR%\ko.po" (
    echo [1/3] Refreshing ko.po from source...
    "%GETTEXT_DIR%\xgettext.exe" --keyword=_ --keyword=N_ --keyword=C_:1c,2 ^
        --from-code=UTF-8 --language=C --no-location ^
        -o "%PO_DIR%\nethack_build.pot" ^
        src\*.c include\*.h win\win32\mswproc.c 2>nul
    if not errorlevel 1 (
        "%GETTEXT_DIR%\msgmerge.exe" --update --backup=none --no-fuzzy-matching ^
            "%PO_DIR%\ko.po" "%PO_DIR%\nethack_build.pot" 2>nul
    ) else (
        echo WARNING: xgettext failed, using existing ko.po as-is.
    )
    del "%PO_DIR%\nethack_build.pot" 2>nul
) else (
    echo [1/3] Skipping ko.po refresh - file is absent (treated as ko_manual.po-only build^).
)

REM Step 2: Quick sanity stats.
echo [2/3] Checking translation quality...
set FUZZY_COUNT=0
if exist "%PO_DIR%\ko.po" (
    for /f %%a in ('findstr /c:"#, fuzzy" "%PO_DIR%\ko.po" ^| find /c /v ""') do set FUZZY_COUNT=%%a
    if %FUZZY_COUNT% GTR 0 (
        echo WARNING: %FUZZY_COUNT% fuzzy translations found in ko.po
        echo          Review these entries - they may be incorrectly matched.
    )
    set UNTRANSLATED=0
    for /f %%a in ('findstr /c:"msgstr """"" "%PO_DIR%\ko.po" ^| find /c /v ""') do set UNTRANSLATED=%%a
    echo       %UNTRANSLATED% untranslated entries (ko.po^).
)

if "%1"=="--check-only" (
    echo Check complete.
    exit /b 0
)

REM Step 3: Merge ko_manual.po (priority) + ko.po (if present), then compile .mo.
echo [3/3] Merging and compiling message catalog...
if not exist "%LOCALE_DIR%" mkdir "%LOCALE_DIR%"

if exist "%PO_DIR%\ko_manual.po" (
    if exist "%PO_DIR%\ko.po" (
        echo       Merging ko_manual.po + ko.po (manual entries take priority^)...
        "%GETTEXT_DIR%\msgcat.exe" --use-first -o "%PO_DIR%\ko_merged.po" "%PO_DIR%\ko_manual.po" "%PO_DIR%\ko.po"
    ) else (
        echo       Using ko_manual.po directly (no local ko.po cache^)...
        copy /y "%PO_DIR%\ko_manual.po" "%PO_DIR%\ko_merged.po" >nul
    )
    "%GETTEXT_DIR%\msgfmt.exe" -o "%LOCALE_DIR%\nethack.mo" "%PO_DIR%\ko_merged.po"
) else (
    "%GETTEXT_DIR%\msgfmt.exe" -o "%LOCALE_DIR%\nethack.mo" "%PO_DIR%\ko.po"
)
if errorlevel 1 (
    echo ERROR: msgfmt failed to compile translations
    exit /b 1
)

echo === Translation build complete ===
endlocal
exit /b 0
