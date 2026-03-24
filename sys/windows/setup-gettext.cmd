@echo off
REM Setup gettext (libintl) for HanNetHack Windows build
REM This script downloads prebuilt gettext binaries and creates
REM an MSVC-compatible import library for libintl.

setlocal enabledelayedexpansion

if not exist lib\* mkdir lib

set GETTEXT_VERSION=0.21
set ICONV_VERSION=1.16
set GETTEXT_URL=https://github.com/mlocati/gettext-iconv-windows/releases/download/v%GETTEXT_VERSION%-v%ICONV_VERSION%/gettext%GETTEXT_VERSION%-iconv%ICONV_VERSION%-shared-64.zip
set GETTEXT_ZIP=lib\gettext.zip
set GETTEXT_DIR=lib\gettext
set INTL_DIR=lib\libintl

if exist "%INTL_DIR%\lib\intl.lib" (
    echo libintl is already set up in %INTL_DIR%
    goto :eof
)

echo === Downloading gettext %GETTEXT_VERSION% ===
curl -L "%GETTEXT_URL%" -o "%GETTEXT_ZIP%"
if errorlevel 1 (
    echo ERROR: Failed to download gettext. Check your internet connection.
    goto :eof
)

echo === Extracting gettext ===
if not exist "%GETTEXT_DIR%" mkdir "%GETTEXT_DIR%"
tar -xf "%GETTEXT_ZIP%" -C "%GETTEXT_DIR%"
del "%GETTEXT_ZIP%"

echo === Creating libintl header ===
if not exist "%INTL_DIR%\include" mkdir "%INTL_DIR%\include"
if not exist "%INTL_DIR%\lib" mkdir "%INTL_DIR%\lib"

(
echo #ifndef _LIBINTL_H
echo #define _LIBINTL_H 1
echo #ifdef __cplusplus
echo extern "C" {
echo #endif
echo #ifdef _MSC_VER
echo #define LIBINTL_DLL_IMPORTED __declspec(dllimport^)
echo #else
echo #define LIBINTL_DLL_IMPORTED
echo #endif
echo extern LIBINTL_DLL_IMPORTED char *gettext(const char *__msgid^);
echo extern LIBINTL_DLL_IMPORTED char *dgettext(const char *__domainname, const char *__msgid^);
echo extern LIBINTL_DLL_IMPORTED char *dcgettext(const char *__domainname, const char *__msgid, int __category^);
echo extern LIBINTL_DLL_IMPORTED char *ngettext(const char *__msgid1, const char *__msgid2, unsigned long int __n^);
echo extern LIBINTL_DLL_IMPORTED char *dngettext(const char *__domainname, const char *__msgid1, const char *__msgid2, unsigned long int __n^);
echo extern LIBINTL_DLL_IMPORTED char *dcngettext(const char *__domainname, const char *__msgid1, const char *__msgid2, unsigned long int __n, int __category^);
echo extern LIBINTL_DLL_IMPORTED char *textdomain(const char *__domainname^);
echo extern LIBINTL_DLL_IMPORTED char *bindtextdomain(const char *__domainname, const char *__dirname^);
echo extern LIBINTL_DLL_IMPORTED char *bind_textdomain_codeset(const char *__domainname, const char *__codeset^);
echo #ifdef __cplusplus
echo }
echo #endif
echo #endif
) > "%INTL_DIR%\include\libintl.h"

echo === Creating import library definition ===
(
echo LIBRARY libintl-8
echo EXPORTS
echo     gettext
echo     dgettext
echo     dcgettext
echo     ngettext
echo     dngettext
echo     dcngettext
echo     textdomain
echo     bindtextdomain
echo     bind_textdomain_codeset
) > "%INTL_DIR%\libintl.def"

echo === Generating MSVC import library ===
REM Find lib.exe from Visual Studio
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set VSINSTALL=%%i

if not defined VSINSTALL (
    echo ERROR: Visual Studio not found. Please run this from Developer Command Prompt
    echo        or ensure Visual Studio is installed.
    goto :eof
)

REM Try to find lib.exe
set "FOUND_LIB="
for /r "%VSINSTALL%\VC\Tools\MSVC" %%f in (lib.exe) do (
    if "%%~nxf"=="lib.exe" (
        echo %%~dpf | findstr /i "Hostx64\\x64" >nul
        if not errorlevel 1 (
            set "FOUND_LIB=%%f"
        )
    )
)

if not defined FOUND_LIB (
    echo ERROR: lib.exe not found. Please install "Desktop development with C++" workload.
    goto :eof
)

pushd "%INTL_DIR%"
"%FOUND_LIB%" /def:libintl.def /out:lib\intl.lib /machine:x64
popd

if exist "%INTL_DIR%\lib\intl.lib" (
    echo.
    echo === Success ===
    echo libintl header:  %INTL_DIR%\include\libintl.h
    echo Import library:  %INTL_DIR%\lib\intl.lib
    echo Runtime DLLs:    %GETTEXT_DIR%\bin\libintl-8.dll
    echo.
    echo After building, copy these DLLs to the output directory:
    echo   copy %GETTEXT_DIR%\bin\libintl-8.dll binary\Release\x64\
    echo   copy %GETTEXT_DIR%\bin\libiconv-2.dll binary\Release\x64\
    echo   copy %GETTEXT_DIR%\bin\libgcc_s_seh-1.dll binary\Release\x64\
    echo   copy %GETTEXT_DIR%\bin\libwinpthread-1.dll binary\Release\x64\
) else (
    echo ERROR: Failed to create import library.
)

endlocal
