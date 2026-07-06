# 봉화(Bonghwa) — rollback.ps1
# 사용: .\rollback.ps1            → 직전 릴리즈로 복귀
#       .\rollback.ps1 -Release C:\bonghwa\releases\20260703_..._abcd1234
param(
    [string]$Release
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\bonghwa.config.ps1"
$C = $BonghwaConfig

if (-not $Release) {
    $current = (Get-Item $C.LiveJunction).Target
    $Release = Get-Content $C.HistoryFile |
        Where-Object { $_ -match '\|DEPLOY\|' } |
        ForEach-Object { ($_ -split '\|')[3] } |
        Where-Object { $_ -ne $current -and (Test-Path $_) } |
        Select-Object -Last 1
}

if (-not $Release -or -not (Test-Path $Release)) {
    Write-Error "[rollback] no previous release found (target='$Release')"
    exit 1
}

& cmd /c rmdir "$($C.LiveJunction)"
& cmd /c mklink /J "$($C.LiveJunction)" "$Release" | Out-Null

Import-Module WebAdministration -ErrorAction SilentlyContinue
if (Get-Module WebAdministration) {
    Restart-WebAppPool -Name $C.AppPoolName -ErrorAction SilentlyContinue
}

"$(Get-Date -Format o)|ROLLBACK|-|$Release" | Add-Content $C.HistoryFile
Write-Host "[rollback] DONE. live -> $Release"
