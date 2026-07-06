# 봉화(Bonghwa) 설정 — 환경별 경로는 전부 여기서만. (예시값, 실서버에서 수정)
# 비밀값(계정/토큰)은 이 파일에도 넣지 말 것 → Windows 자격증명관리자/환경변수 사용.

$BonghwaConfig = @{
    # 빌드
    MSBuildPath   = "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
    SolutionFile  = "MyApp.sln"          # 리포지토리 루트 기준 상대경로
    BuildConfig   = "Release"
    PublishOutput = "bin\Release"        # 빌드 산출물 폴더 (솔루션 기준)

    # 배포
    WorkDir       = "C:\bonghwa\work"        # checkout 작업 폴더
    ReleasesDir   = "C:\bonghwa\releases"    # 릴리즈 보관
    LiveJunction  = "C:\inetpub\wwwroot\app"  # IIS가 바라보는 junction
    HistoryFile   = "C:\bonghwa\history.log"

    # IIS
    AppPoolName   = "DefaultAppPool"     # 배포 전후 recycle 대상
    KeepReleases  = 10                   # 오래된 릴리즈 자동 정리 개수
}
