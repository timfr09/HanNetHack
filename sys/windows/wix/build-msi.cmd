@echo off
REM ============================================================================
REM Build HanNetHack MSI installer locally
REM
REM Prerequisites:
REM   * `nmake package` already run successfully (binary\ populated, including
REM     locale\ tree, gettext DLLs, NetHack(W).exe, nhdat370, etc.)
REM   * .NET SDK 6+ installed (for the WiX v4 dotnet-tool)
REM   * Run from the repository root, OR pass the repo root as the working
REM     directory.
REM
REM Usage (from repo root):
REM     sys\windows\wix\build-msi.cmd [version]
REM
REM Defaults:
REM     version = 3.7.0.0   (when no argument is given)
REM
REM Output:
REM     package\hannethack-<version>-win-x64.msi
REM ============================================================================

setlocal enabledelayedexpansion

REM ----- Locate repo root (this script is at sys\windows\wix\) -----
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%..\..\.." || (
    echo ERROR: cannot cd to repo root from %SCRIPT_DIR%
    exit /b 1
)
set "REPO_ROOT=%CD%"
popd

set "BIN_DIR=%REPO_ROOT%\binary"
set "PKG_DIR=%REPO_ROOT%\package"
set "WIX_DIR=%REPO_ROOT%\sys\windows\wix"

if not exist "%BIN_DIR%\NetHackW.exe" (
    echo ERROR: %BIN_DIR%\NetHackW.exe not found.
    echo        Run `nmake package` from src\ first.
    exit /b 1
)

if not exist "%PKG_DIR%" mkdir "%PKG_DIR%"

REM ----- Version (must be Major.Minor.Build[.Revision], all numeric) -----
set "VERSION=%~1"
if "%VERSION%"=="" set "VERSION=3.7.0.0"

REM ----- Make sure WiX v5 CLI is available -----
REM v5 is the lowest version that supports <Files Include="..."> auto-harvest.
REM We avoid v6+ because it requires accepting the OSMF EULA on every run.
where wix >nul 2>&1
if errorlevel 1 (
    echo === Installing WiX v5 (dotnet tool) ===
    dotnet tool install --global wix --version 5.0.2
    if errorlevel 1 (
        echo ERROR: dotnet tool install failed. Install .NET SDK 6+ first:
        echo        https://dotnet.microsoft.com/download
        exit /b 1
    )
)

REM ----- Make sure the WixUI extension is installed (must match CLI line) -----
wix extension list -g 2>nul | findstr /I "WixToolset.UI.wixext" >nul
if errorlevel 1 (
    echo === Installing WixToolset.UI.wixext 5.0.2 ===
    wix extension add -g WixToolset.UI.wixext/5.0.2
)

set "MSI_OUT=%PKG_DIR%\hannethack-%VERSION%-win-x64.msi"

echo === Building MSI ===
echo   Source : %WIX_DIR%\Package.wxs
echo   Files  : %BIN_DIR%
echo   Output : %MSI_OUT%
echo.

pushd "%WIX_DIR%"
wix build Package.wxs ^
    -arch x64 ^
    -d Version=%VERSION% ^
    -d "BinaryDir=%BIN_DIR%" ^
    -ext WixToolset.UI.wixext ^
    -o "%MSI_OUT%"
set "RC=%ERRORLEVEL%"
popd

if not "%RC%"=="0" (
    echo ERROR: wix build failed (exit %RC%^).
    exit /b %RC%
)

echo.
echo === MSI built ===
echo %MSI_OUT%
endlocal
exit /b 0
