# 봉화(Bonghwa) — deploy.ps1
# post-receive hook에서 호출. checkout → MSBuild → junction 스위칭 → 이력 기록.
param(
    [Parameter(Mandatory)] [string]$Commit,
    [Parameter(Mandatory)] [string]$RepoPath   # bare repo 경로 (hook의 $GIT_DIR)
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\bonghwa.config.ps1"
$C = $BonghwaConfig

function Log($msg) { Write-Host "[deploy] $msg" }
function Write-BonghwaHistory($action, $commit, $release) {
    "$(Get-Date -Format o)|$action|$commit|$release" | Add-Content -Path $C.HistoryFile
}

try {
    # 1. checkout
    Log "1/5 checkout $Commit"
    if (Test-Path $C.WorkDir) { Remove-Item $C.WorkDir -Recurse -Force }
    New-Item -ItemType Directory -Path $C.WorkDir -Force | Out-Null
    & git --git-dir="$RepoPath" --work-tree="$($C.WorkDir)" checkout -f $Commit
    if ($LASTEXITCODE -ne 0) { throw "git checkout failed" }

    # 2. MSBuild
    Log "2/5 MSBuild ($($C.BuildConfig))"
    $sln = Join-Path $C.WorkDir $C.SolutionFile
    & $C.MSBuildPath $sln /t:Rebuild /p:Configuration=$($C.BuildConfig) /v:minimal /nologo
    if ($LASTEXITCODE -ne 0) { throw "MSBuild failed (exit $LASTEXITCODE)" }

    # 3. 릴리즈 폴더 생성
    # ASP.NET Web Application은 bin(컴파일 산출물)과 콘텐츠(aspx/web.config 등)가
    # 같은 폴더에 있어야 IIS가 서빙한다 — MSBuild _CopyWebApplication 타깃은 이 조합이
    # 기대대로 안 맞아 프로젝트 폴더를 obj만 빼고 그대로 복사하는 방식으로 대체.
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $releaseDir = Join-Path $C.ReleasesDir "${stamp}_$($Commit.Substring(0,8))"
    Log "3/5 stage release → $releaseDir"
    $projectDir = Join-Path $C.WorkDir $C.PublishOutput
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    Get-ChildItem $projectDir -Exclude obj | Copy-Item -Destination $releaseDir -Recurse -Force
    "built=$Commit at=$stamp" | Set-Content (Join-Path $releaseDir "BUILD_INFO.txt")

    # 4. junction 스위칭 (원자적 교체 — IIS 무중단에 가까운 전환)
    Log "4/5 switch junction → $releaseDir"
    if (Test-Path $C.LiveJunction) {
        & cmd /c rmdir "$($C.LiveJunction)"   # junction만 제거, 대상은 보존
    }
    & cmd /c mklink /J "$($C.LiveJunction)" "$releaseDir" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "junction switch failed" }

    # app pool recycle (junction 캐시 문제 방지)
    Import-Module WebAdministration -ErrorAction SilentlyContinue
    if (Get-Module WebAdministration) {
        Restart-WebAppPool -Name $C.AppPoolName -ErrorAction SilentlyContinue
    }

    # 5. 이력 + 오래된 릴리즈 정리
    Log "5/5 record history"
    Write-BonghwaHistory "DEPLOY" $Commit $releaseDir
    Get-ChildItem $C.ReleasesDir -Directory | Sort-Object Name -Descending |
        Select-Object -Skip $C.KeepReleases | Remove-Item -Recurse -Force

    Log "DONE. live -> $releaseDir"
}
catch {
    Log "FAIL: $_"
    Write-BonghwaHistory "DEPLOY_FAIL" $Commit "$_"
    exit 1
}
