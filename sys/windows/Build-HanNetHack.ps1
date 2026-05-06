#requires -Version 5.1
<#
.SYNOPSIS
  HanNetHack Windows 빌드 — Visual Studio 솔루션(MSBuild) + 선택적 번역 컴파일 + 설치 스테이징

.DESCRIPTION
  저장소 루트( sys\windows\vs\NetHack.sln 이 있는 폴더 )를 자동으로 찾습니다.
  Lua / PDCursesMod 가 없으면 PowerShell(Invoke-WebRequest + tar)로 받습니다.
  빌드 후 기본으로 sys\windows\install.cmd 를 실행해 install\HanNetHack\ 에 복사합니다.

.EXAMPLE
  .\sys\windows\Build-HanNetHack.ps1

.EXAMPLE
  .\sys\windows\Build-HanNetHack.ps1 -CompilePo -Target Build

.EXAMPLE
  .\sys\windows\Build-HanNetHack.ps1 -SkipFetch -SkipInstall
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Release',

    [ValidateSet('x64', 'Win32', 'ARM64')]
    [string] $Platform = 'x64',

    [ValidateSet('Build', 'Rebuild', 'Clean')]
    [string] $Target = 'Rebuild',

    # lib 에 이미 있으면 생략. 강제로 받으려면 -Fetch
    [switch] $Fetch,

    [switch] $SkipFetch,

    # po/ko_manual.po -> dat/locale/ko/nethack.mo (msgfmt / WSL make compile)
    [switch] $CompilePo,

    [switch] $SkipInstall,

    # fetch.cmd 만 실행하고 종료
    [switch] $FetchOnly,

    # 이미 빌드된 binary\... 만 install\HanNetHack\ 로 복사
    [switch] $InstallOnly,

    [string] $MSBuildPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $dir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
    $dir = (Resolve-Path -LiteralPath $dir).Path
    while ($true) {
        $sln = Join-Path $dir 'sys\windows\vs\NetHack.sln'
        if (Test-Path -LiteralPath $sln) {
            return $dir
        }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or ($parent -eq $dir)) {
            throw 'HanNetHack 저장소 루트를 찾을 수 없습니다. sys\windows\vs\NetHack.sln 이 포함된 클론에서 실행하세요.'
        }
        $dir = $parent
    }
}

function Test-LuaPresent {
    param([string] $Root)
    Test-Path (Join-Path $Root 'lib\lua-5.4.8\src\lapi.c')
}

function Test-PdcPresent {
    param([string] $Root)
    Test-Path (Join-Path $Root 'lib\pdcursesmod\pdcurses\addch.c')
}

function Get-WindowsSystemTar {
    # Git Bash/MSYS 의 tar.exe 가 PATH 앞에 있으면 .zip 을 잘못 처리함 → Win10+ 기본 tar 고정
    $sys = Join-Path $env:WINDIR 'System32\tar.exe'
    if (Test-Path -LiteralPath $sys) {
        return $sys
    }
    return 'tar.exe'
}

function Ensure-Tls12 {
    $proto = [Net.SecurityProtocolType]::Tls12
    if (([Net.ServicePointManager]::SecurityProtocol -band $proto) -ne $proto) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $proto
    }
}

function Invoke-FetchLua {
    param([string] $LibDir)
    $ver = '5.4.8'
    $tarName = "lua-$ver.tar.gz"
    $luaRoot = Join-Path $LibDir "lua-$ver"
    if (Test-Path -LiteralPath $luaRoot) {
        Remove-Item -LiteralPath $luaRoot -Recurse -Force
    }
    $url = "https://www.lua.org/ftp/$tarName"
    $tarball = Join-Path $LibDir $tarName
    Write-Host "    GET $url" -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $url -OutFile $tarball -UseBasicParsing
    $tarExe = Get-WindowsSystemTar
    $tx = Start-Process -FilePath $tarExe -ArgumentList @('-xzf', $tarName) -WorkingDirectory $LibDir `
        -Wait -PassThru -NoNewWindow
    if ($tx.ExitCode -ne 0) {
        throw "tar extract Lua failed (exit $($tx.ExitCode))"
    }
    Remove-Item -LiteralPath $tarball -Force -ErrorAction SilentlyContinue
}

function Invoke-FetchPdcurses {
    param([string] $LibDir)
    $ver = '4.4.0'
    $zipName = 'pdcursesmod.zip'
    $url = "https://github.com/Bill-Gray/PDCursesMod/archive/refs/tags/v$ver.zip"
    $zipPath = Join-Path $LibDir $zipName
    $dest = Join-Path $LibDir 'pdcursesmod'
    Write-Host "    GET $url" -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    if (Test-Path -LiteralPath $dest) {
        Remove-Item -LiteralPath $dest -Recurse -Force
    }
    New-Item -ItemType Directory -Path $dest | Out-Null
    $tarExe = Get-WindowsSystemTar
    $tx = Start-Process -FilePath $tarExe `
        -ArgumentList @('-xf', $zipName, '-C', 'pdcursesmod', '--strip-components=1') `
        -WorkingDirectory $LibDir -Wait -PassThru -NoNewWindow
    if ($tx.ExitCode -ne 0) {
        throw "tar extract PDCursesMod failed (exit $($tx.ExitCode))"
    }
    Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
}

function Invoke-FetchPrerequisites {
    param([string] $Root, [switch] $Force)
    Ensure-Tls12
    $lib = Join-Path $Root 'lib'
    if (-not (Test-Path -LiteralPath $lib)) {
        New-Item -ItemType Directory -Path $lib | Out-Null
    }

    $needLua = $Force -or -not (Test-LuaPresent $Root)
    $needPdc = $Force -or -not (Test-PdcPresent $Root)

    if ($needLua) {
        Write-Host '==> Fetch: Lua 5.4.8' -ForegroundColor Cyan
        Invoke-FetchLua -LibDir $lib
        if (-not (Test-LuaPresent $Root)) { throw 'Lua 설치 후에도 lib\lua-5.4.8\src\lapi.c 가 없습니다.' }
    }

    if ($needPdc) {
        Write-Host '==> Fetch: PDCursesMod' -ForegroundColor Cyan
        Invoke-FetchPdcurses -LibDir $lib
        if (-not (Test-PdcPresent $Root)) { throw 'PDCursesMod 설치 후에도 lib\pdcursesmod\pdcurses\addch.c 가 없습니다.' }
    }
}

function Invoke-InstallStaging {
    param([string] $Root, [string] $Configuration, [string] $Platform)
    $installCmd = Join-Path $Root 'sys\windows\install.cmd'
    $p = Start-Process -FilePath $installCmd -ArgumentList @($Configuration, $Platform) `
        -WorkingDirectory $Root -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -ne 0) {
        throw "install.cmd failed with exit $($p.ExitCode)"
    }
}

function Find-MSBuild {
    param([string] $ExplicitPath)
    if ($ExplicitPath -and (Test-Path -LiteralPath $ExplicitPath)) {
        return (Resolve-Path $ExplicitPath).Path
    }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $candidates = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
            -find 'MSBuild\**\Bin\MSBuild.exe' 2>$null
        if ($candidates) {
            return ($candidates | Select-Object -First 1)
        }
    }
    $fallback = 'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe'
    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }
    throw 'MSBuild.exe 를 찾지 못했습니다. Visual Studio 2022(C++) 설치 또는 -MSBuildPath 로 지정하세요.'
}

function Invoke-CompilePo {
    param([string] $Root)
    $poDir = Join-Path $Root 'po'
    $gettextBinDir = Join-Path $Root 'lib\gettext\bin'

    if (Test-Path (Join-Path $gettextBinDir 'msgfmt.exe')) {
        $env:PATH = "$gettextBinDir;$env:PATH"
    }

    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wsl) {
        # Avoid wslpath dependency/quoting pitfalls; convert C:\... directly.
        $unixRoot = $null
        if ($Root -match '^([A-Za-z]):\\(.*)$') {
            $drive = $Matches[1].ToLowerInvariant()
            $rest = $Matches[2].Replace('\', '/')
            $unixRoot = "/mnt/$drive/$rest"
        }

        if ($unixRoot) {
            try {
                # Use WSL path only when make is available there.
                $hasMake = (wsl.exe -e bash -lc "command -v make >/dev/null 2>&1; echo `$?") | Select-Object -First 1
                if ($hasMake -eq '0') {
                    Write-Host '==> po: WSL make compile' -ForegroundColor Cyan
                    wsl.exe -e bash -lc "set -e; cd '$unixRoot/po' && make compile"
                    if ($LASTEXITCODE -eq 0) { return }
                }
            } catch {
                Write-Warning "WSL make compile 실패, 다른 경로로 재시도합니다: $($_.Exception.Message)"
            }
        }
    }

    $make = Get-Command make -ErrorAction SilentlyContinue
    $msgfmt = Get-Command msgfmt -ErrorAction SilentlyContinue
    if ($make -and $msgfmt) {
        Write-Host '==> po: make compile (PATH에 make, msgfmt)' -ForegroundColor Cyan
        Push-Location $poDir
        try {
            & make compile
        } finally {
            Pop-Location
        }
        return
    }

    # Final fallback for Windows-only environments:
    # generate nethack.mo directly from canonical ko_manual.po.
    if (Test-Path (Join-Path $gettextBinDir 'msgfmt.exe')) {
        Write-Host '==> po: msgfmt direct compile fallback' -ForegroundColor Yellow
        $msgfmtExe = Join-Path $gettextBinDir 'msgfmt.exe'
        $srcPo = Join-Path $poDir 'ko_manual.po'
        $dstMo = Join-Path $Root 'dat\locale\ko\nethack.mo'
        & $msgfmtExe -o $dstMo $srcPo
        if ($LASTEXITCODE -eq 0) { return }
    }

    throw @'
po 컴파일을 할 수 없습니다.
  · 권장: WSL 설치 후 다시 실행하거나, WSL에서 `cd po && make compile`
  · 또는 sys\windows\setup-gettext.cmd 로 msgfmt를 두고 PATH에 make/msgfmt 준비
'@
}

$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot

if ($InstallOnly) {
    Write-Host "==> Install only -> sys\windows\install.cmd $Configuration $Platform" -ForegroundColor Cyan
    Invoke-InstallStaging -Root $RepoRoot -Configuration $Configuration -Platform $Platform
    exit 0
}

if (-not $SkipFetch) {
    $needFetch = $Fetch -or -not (Test-LuaPresent $RepoRoot) -or -not (Test-PdcPresent $RepoRoot)
    if ($needFetch) {
        Invoke-FetchPrerequisites -Root $RepoRoot -Force:$Fetch
    } else {
        Write-Host '==> Fetch: lib 에 Lua / PDCursesMod 가 있어 생략 (-Fetch 로 강제 가능)' -ForegroundColor DarkGray
    }
}

if ($FetchOnly) {
    Write-Host '==> -FetchOnly 로 종료합니다.' -ForegroundColor Green
    exit 0
}

if ($CompilePo) {
    Invoke-CompilePo -Root $RepoRoot
}

$msbuild = Find-MSBuild -ExplicitPath $MSBuildPath
$sln = Join-Path $RepoRoot 'sys\windows\vs\NetHack.sln'

Write-Host "==> MSBuild: $Target  $Configuration | $Platform" -ForegroundColor Cyan
Write-Host "    $msbuild" -ForegroundColor DarkGray

$args = @(
    $sln
    "/t:$Target"
    "/p:Configuration=$Configuration"
    "/p:Platform=$Platform"
    '/m'
)
& $msbuild @args
if ($LASTEXITCODE -ne 0) {
    throw "MSBuild failed with exit code $LASTEXITCODE"
}

$binExe = Join-Path $RepoRoot "binary\$Configuration\$Platform\NetHack.exe"
$binExeW = Join-Path $RepoRoot "binary\$Configuration\$Platform\NetHackW.exe"
if (-not (Test-Path -LiteralPath $binExe)) {
    Write-Warning "예상 출력이 없습니다: $binExe"
}
elseif (Test-Path -LiteralPath $binExeW) {
    $t1 = (Get-Item -LiteralPath $binExe).LastWriteTimeUtc
    $t2 = (Get-Item -LiteralPath $binExeW).LastWriteTimeUtc
    $deltaMin = [math]::Abs(($t1 - $t2).TotalMinutes)
    if ($deltaMin -gt 2) {
        Write-Warning @"
NetHack.exe와 NetHackW.exe의 빌드 시각이 약 $([math]::Round($deltaMin, 1))분 차이 납니다. 한쪽만 증분 빌드된 경우입니다.
전체 솔루션 Rebuild (.\sys\windows\Build-HanNetHack.ps1 -Target Rebuild) 후 다시 설치하면 둘 다 같은 시각에 맞춰집니다.
"@
    }
}

if (-not $SkipInstall) {
    Write-Host "==> sys\windows\install.cmd $Configuration $Platform" -ForegroundColor Cyan
    Invoke-InstallStaging -Root $RepoRoot -Configuration $Configuration -Platform $Platform
    Write-Host ''
    Write-Host '완료: install\HanNetHack\NetHack.exe / NetHackW.exe' -ForegroundColor Green
} else {
    Write-Host '완료: 빌드 출력은 binary\ 에 있습니다 (-SkipInstall).' -ForegroundColor Green
}

exit 0
