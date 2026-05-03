#requires -Version 5.1
<#
  호환용 진입점 — 실제 스크립트는 sys\windows\Build-HanNetHack.ps1 입니다.
  저장소 루트에서 .\Build-HanNetHack.ps1 로 실행해도 동일하게 동작합니다.
#>
$ErrorActionPreference = 'Stop'
$inner = Join-Path $PSScriptRoot 'sys\windows\Build-HanNetHack.ps1'
if (-not (Test-Path -LiteralPath $inner)) {
    throw "스크립트를 찾을 수 없습니다: $inner"
}
& $inner @args
exit $LASTEXITCODE
