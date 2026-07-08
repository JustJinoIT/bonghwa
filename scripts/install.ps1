# 봉화(Bonghwa) — install.ps1
# Windows 서버 사전점검 + 작업 디렉토리 준비 + (선택) Gitea post-receive hook 설치
param(
    [string]$GiteaRepoPath   # 지정 시 hooks/post-receive를 <path>\hooks\post-receive 로 복사
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\bonghwa.config.ps1"
$C = $BonghwaConfig

$fail = @()

function Check {
    param([string]$Name, [scriptblock]$Test, [string]$Hint)
    Write-Host -NoNewline "[check] $Name ... "
    if (& $Test) {
        Write-Host "OK"
    }
    else {
        Write-Host "FAIL"
        $script:fail += "${Name}: $Hint"
    }
}

# 1. MSBuild — 설정 경로에 없으면 vswhere로 자동 탐색해 안내만 하고 config는 직접 수정하게 한다
Write-Host -NoNewline "[check] MSBuild ... "
if (Test-Path $C.MSBuildPath) {
    Write-Host "OK ($($C.MSBuildPath))"
}
else {
    Write-Host "FAIL (설정된 경로 없음: $($C.MSBuildPath))"
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $found = & $vswhere -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" 2>$null
        if ($found) {
            Write-Host "  -> vswhere 탐색 결과: $found"
            Write-Host "  -> bonghwa.config.ps1의 MSBuildPath를 위 경로로 수정하세요."
        }
        else {
            Write-Host "  -> vswhere로도 못 찾음. Visual Studio Build Tools 설치 필요."
        }
    }
    else {
        Write-Host "  -> vswhere.exe도 없음 ($vswhere). Visual Studio Build Tools 미설치로 추정."
    }
    $fail += "MSBuild: bonghwa.config.ps1 MSBuildPath 확인/vswhere 탐색 결과 참고"
}

# 2. git
Check -Name "git" -Test { [bool](Get-Command git -ErrorAction SilentlyContinue) } -Hint "git for Windows 설치 필요 (PATH 등록 확인)"

# 3. sh.exe — Gitea가 post-receive 훅 발화에 사용하는 필수 의존성
$shPath = "C:\Program Files\Git\usr\bin\sh.exe"
Check -Name "sh.exe ($shPath)" -Test { Test-Path $shPath } -Hint "Git for Windows 표준 설치 경로에 없음 — Gitea가 post-receive 훅을 발화하지 못함"

# 4. IIS (W3SVC)
Check -Name "IIS (W3SVC)" -Test { [bool](Get-Service W3SVC -ErrorAction SilentlyContinue) } -Hint "IIS 미설치 또는 서비스 없음"

# 5. 작업 디렉토리 준비
Write-Host ""
Write-Host "[setup] 디렉토리 준비"
foreach ($dir in @($C.WorkDir, $C.ReleasesDir, (Split-Path $C.HistoryFile -Parent))) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  생성: $dir"
    }
    else {
        Write-Host "  존재: $dir"
    }
}

# 6. Gitea post-receive hook 설치 (선택)
if ($GiteaRepoPath) {
    Write-Host ""
    Write-Host "[setup] Gitea post-receive hook 설치 -> $GiteaRepoPath"
    if (-not (Test-Path $GiteaRepoPath)) {
        throw "GiteaRepoPath 없음: $GiteaRepoPath"
    }
    $hooksDir = Join-Path $GiteaRepoPath "hooks"
    if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }
    $src = Join-Path $PSScriptRoot "..\hooks\post-receive"

    # 훅의 BONGHWA_HOME 기본값(C:/bonghwa)을 install.ps1이 실제로 실행된 위치로
    # 치환한다. 하드코딩된 기본값은 이 스크립트가 설치되는 서버마다 다를 수 있어
    # 실제로 안 맞는 경우(예: CI 러너)가 있었다 — 설치 시점에 자동으로 맞춘다.
    $bonghwaHome = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path -replace '\\', '/'
    $hookContent = Get-Content $src -Raw
    $hookContent = $hookContent.Replace('${BONGHWA_HOME:-C:/bonghwa}', "`${BONGHWA_HOME:-$bonghwaHome}")
    [System.IO.File]::WriteAllText((Join-Path $hooksDir "post-receive"), $hookContent)
    Write-Host "  복사 완료: $(Join-Path $hooksDir 'post-receive') (BONGHWA_HOME=$bonghwaHome)"
}

Write-Host ""
if ($fail.Count -gt 0) {
    Write-Host "[install] 사전점검 실패 항목 $($fail.Count)건:"
    $fail | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
else {
    Write-Host "[install] 사전점검 전부 통과. 준비 완료."
}
