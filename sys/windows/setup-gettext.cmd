@echo off
REM Download gettext / iconv *command-line tools* for HanNetHack (Windows).
REM
REM HanNetHack no longer links libintl or ships gettext runtime DLLs.
REM Translations load from nhdat via src/mo_reader.c (XOR .mox catalog).
REM This script only installs msgfmt, msgcat, xgettext, etc. under
REM lib\gettext\bin\ — needed when you edit po/*.po, run
REM sys\windows\build-translations.cmd, or run nmake package (which
REM rebuilds dat\locale\ko\nethack.mox).
REM
REM Pin matches .github/workflows/release.yml.

setlocal enabledelayedexpansion

if not exist lib\* mkdir lib

set GETTEXT_VER=1.0
set ICONV_VER=1.19
set BASE=https://github.com/mlocati/gettext-iconv-windows/releases/download
set BUNDLE=v%GETTEXT_VER%-v%ICONV_VER%
set ZIP=gettext%GETTEXT_VER%-iconv%ICONV_VER%-shared-64.zip
set GETTEXT_ZIP=lib\gettext.zip
set GETTEXT_DIR=lib\gettext

if exist "%GETTEXT_DIR%\bin\msgfmt.exe" (
    echo gettext tools already present: %GETTEXT_DIR%\bin
    goto :verify
)

echo === Downloading %ZIP% ===
curl -L "%BASE%/%BUNDLE%/%ZIP%" -o "%GETTEXT_ZIP%"
if errorlevel 1 (
    echo ERROR: download failed. Check your network connection.
    exit /b 1
)

echo === Extracting to %GETTEXT_DIR% ===
if not exist "%GETTEXT_DIR%" mkdir "%GETTEXT_DIR%"
tar -xf "%GETTEXT_ZIP%" -C "%GETTEXT_DIR%"
del "%GETTEXT_ZIP%"

:verify
if not exist "%GETTEXT_DIR%\bin\msgfmt.exe" (
    echo ERROR: msgfmt.exe not found under %GETTEXT_DIR%\bin — archive layout may have changed.
    exit /b 1
)
if not exist "%GETTEXT_DIR%\bin\msgcat.exe" (
    echo ERROR: msgcat.exe not found under %GETTEXT_DIR%\bin — archive layout may have changed.
    exit /b 1
)

echo.
echo === OK ===
echo Tools: %GETTEXT_DIR%\bin\msgfmt.exe (and siblings)
echo.
echo You do NOT need to copy libintl DLLs into binary\ — the game does not use them.

endlocal
exit /b 0
