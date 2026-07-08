# 봉화(Bonghwa) 설정 — 환경별 경로는 전부 여기서만. (예시값, 실서버에서 수정)
# 비밀값(계정/토큰)은 이 파일에도 넣지 말 것 → Windows 자격증명관리자/환경변수 사용.
# CI(GitHub Actions windows-2022, .github/workflows/verify-windows.yml)는 실서버와
# 경로가 달라서 BONGHWA_* 환경변수로 override — 기본값은 항상 실서버 기준을 유지한다.

function Get-BonghwaSetting {
    param([string]$Name, [string]$Default)
    $key = "BONGHWA_$Name"
    # 프로세스 스코프 우선, 없으면 Machine 스코프도 확인한다.
    # Gitea(예약 작업으로 기동)가 스폰하는 hook -> deploy.ps1 프로세스는
    # Actions 스텝의 $env:GITHUB_ENV를 상속받지 못해서 Machine 스코프가 필요하다.
    $v = [Environment]::GetEnvironmentVariable($key)
    if (-not $v) { $v = [Environment]::GetEnvironmentVariable($key, "Machine") }
    if ($v) { return $v } else { return $Default }
}

$BonghwaConfig = @{
    # 빌드
    MSBuildPath   = Get-BonghwaSetting "MSBUILD_PATH" "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    SolutionFile  = "sample-app\SampleApp.sln"   # 리포지토리 루트 기준 상대경로 — 리포에 포함된 실증용 샘플
    BuildConfig   = "Release"
    PublishOutput = "sample-app\SampleApp\bin\Release"   # 빌드 산출물 폴더 (WorkDir 기준)

    # 배포
    WorkDir       = Get-BonghwaSetting "WORK_DIR" "C:\bonghwa\work"        # checkout 작업 폴더
    ReleasesDir   = Get-BonghwaSetting "RELEASES_DIR" "C:\bonghwa\releases"    # 릴리즈 보관
    LiveJunction  = Get-BonghwaSetting "LIVE_JUNCTION" "C:\inetpub\wwwroot\app"  # IIS가 바라보는 junction
    HistoryFile   = Get-BonghwaSetting "HISTORY_FILE" "C:\bonghwa\history.log"

    # IIS
    AppPoolName   = Get-BonghwaSetting "APP_POOL_NAME" "DefaultAppPool"     # 배포 전후 recycle 대상
    KeepReleases  = [int](Get-BonghwaSetting "KEEP_RELEASES" "10")          # 오래된 릴리즈 자동 정리 개수
}
