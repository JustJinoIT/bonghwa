# 봉화(Bonghwa) — bonghwa.ps1
# 단일 진입점 CLI. status/history는 조회, deploy/rollback은 기존 스크립트에 위임.
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet("status", "history", "deploy", "rollback")]
    [string]$Command,

    [string]$Commit,     # deploy 전용
    [string]$RepoPath,   # deploy 전용
    [string]$Release,    # rollback 전용 (미지정 시 직전 릴리즈)
    [int]$Lines = 10     # history 전용
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\bonghwa.config.ps1"
$C = $BonghwaConfig

function Show-Status {
    if (-not (Test-Path $C.LiveJunction)) {
        Write-Host "[status] live junction 없음: $($C.LiveJunction)"
        return
    }
    $target = (Get-Item $C.LiveJunction).Target
    Write-Host "[status] live -> $target"

    $buildInfo = Join-Path $target "BUILD_INFO.txt"
    if (Test-Path $buildInfo) {
        Write-Host "[status] $((Get-Content $buildInfo -Raw).Trim())"
    }

    if (Test-Path $C.HistoryFile) {
        Write-Host "[status] 최근 이력:"
        Get-Content $C.HistoryFile -Tail 3 | ForEach-Object { Write-Host "  $_" }
    }
}

function Show-History {
    if (-not (Test-Path $C.HistoryFile)) {
        Write-Host "[history] 이력 파일 없음: $($C.HistoryFile)"
        return
    }
    Get-Content $C.HistoryFile -Tail $Lines | ForEach-Object {
        $parts = $_ -split '\|', 4
        if ($parts.Count -eq 4) {
            $commitShort = $parts[2].Substring(0, [Math]::Min(8, $parts[2].Length))
            "{0,-25} {1,-12} {2,-10} {3}" -f $parts[0], $parts[1], $commitShort, $parts[3]
        }
        else {
            $_
        }
    }
}

switch ($Command) {
    "status" { Show-Status }
    "history" { Show-History }
    "deploy" {
        if (-not $Commit -or -not $RepoPath) { throw "deploy: -Commit, -RepoPath 필수" }
        & "$PSScriptRoot\deploy.ps1" -Commit $Commit -RepoPath $RepoPath
    }
    "rollback" {
        if ($Release) {
            & "$PSScriptRoot\rollback.ps1" -Release $Release
        }
        else {
            & "$PSScriptRoot\rollback.ps1"
        }
    }
}
