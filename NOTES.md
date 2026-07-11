# 봉화(Bonghwa) — 프로토타입 검증 기록

## 질문
push → hook 발화 → build → 릴리즈 스테이징 → junction 스위칭 → 이력 → 롤백
상태 모델이 end-to-end로 도는가?

## 답 (2026-07-03)
**PASS.** `sim/run_sim.sh` 1회 실행으로 전체 사이클 검증:
- push #1 → 자동 배포 → live = v1 ✅
- push #2 → 자동 배포 → live = v2 ✅
- rollback → live = v1 복귀 ✅
- history.log에 DEPLOY×2 + ROLLBACK×1 기록 ✅
- 非배포 브랜치 push는 무시 (hook 내 branch 필터) ✅

## 확정된 설계 결정
1. **릴리즈 폴더 + junction 스위칭** = 원자적 배포 + 롤백을 공짜로 얻는 구조.
   롤백 = "이전 폴더로 junction 다시 걸기" — 빌드 재실행 불필요.
2. **이력 = append-only 파이프 구분 텍스트 1줄** (`시각|액션|커밋|릴리즈경로`).
   DB 불필요. 롤백 타겟 탐색도 이 파일 grep으로 충분.
3. **hook은 sh, 로직은 PowerShell.** Gitea(Windows)는 Git for Windows sh.exe로
   훅을 실행하므로 sh 훅에서 powershell.exe로 위임하는 게 유일한 접점.
4. 경로/설정은 `bonghwa.config.ps1` 한 곳. 비밀값은 코드·설정 어디에도 없음
   (현재 MVP 범위엔 비밀값 자체가 불필요 — 전부 로컬 파일시스템 작업).

## 실검증 결과 (2026-07-09, GitHub Actions windows-2022 러너)
로컬 접근 가능한 Windows 서버가 없어 GitHub Actions `windows-2022` 러너를
실제 Windows 환경으로 사용해 검증(`.github/workflows/verify-windows.yml`).
sample-app(최소 ASP.NET Framework 4.8 웹앱)을 리포에 포함해 실제 MSBuild+IIS+
Gitea 전체 사이클을 push→build→deploy→실패경로→rollback까지 자동 반복 실행,
전부 PASS 확인.

- [x] MSBuild 실제 빌드 — 확인. ASP.NET Web Application은 `OutputPath=bin\`가
  Debug/Release 공용 플랫 구조라 `bin\Release\`가 아님 (config PublishOutput 수정).
  MSBuild `_CopyWebApplication` 타깃은 기대대로 안 맞아, deploy.ps1이 프로젝트
  폴더를 obj만 제외하고 통째로 복사하는 방식으로 대체 (fix 커밋 참고).
- [x] Gitea custom hook 등록 방식 확인 — **파일 직접 배치**로 확정.
  `install.ps1 -GiteaRepoPath`가 bare repo의 `hooks/post-receive`에 파일을 직접
  복사. Gitea는 표준 git hook을 그대로 실행 — 별도 관리 UI 등록 불필요.
- [x] **IIS junction 스위칭 시 파일 잠금 — 실증 완료 (2026-07-11).** CI에서만
  `KEEP_RELEASES=3`으로 낮추고 v4~v8 5회 연속 배포로 정리(cleanup) 코드 경로를
  실제로 태움. 5회 모두 배포 확인 OK, 릴리즈 폴더는 정확히 3개로 정리, 파일
  잠금으로 인한 `Remove-Item` 실패 없음 (`VERIFY 5/6`). 단, 검증 스크립트 자체에
  스코핑 버그가 있었음 — history.log를 job 전체로 훑어서 VERIFY 3/6이 남긴
  과거 DEPLOY_FAIL까지 걸려 1차 실행은 오탐으로 실패, 이번 구간에 추가된 줄만
  보도록 수정 후 재실행에서 확인 (fix 커밋 참고). **실서버에서 릴리즈가 더
  많이/오래 쌓였을 때(수백 개, 수개월)까지 보장하는 것은 아님** — 이번 검증은
  KeepReleases=3, 5회 반복 범위.
- [x] **push-트리거 배포 vs 수동 rollback 동시 실행 — 실증 완료 (2026-07-11, `VERIFY 6/6`).**
  코드 확인 결과 `deploy.ps1`/`rollback.ps1` 모두 `LiveJunction`에 락 없이
  직접 rmdir+mklink — 실제 운영에서 "push 착신 중 운영자가 rollback 실행"이
  겹칠 수 있는 구조. CI에서 push를 백그라운드 job으로 걸고 300ms 뒤 rollback을
  동시 실행, 최종적으로 junction 유효/사이트 200 응답 확인. **다만 이번 실행은
  진짜 경합이 아니었다** — git의 host-provider 자동탐지 지연(로그에 "auto-detection
  of host provider took too long (>2000ms)")으로 실제 push/hook 시작이 rollback
  완료보다 4초 가까이 늦어져, 사실상 순차 실행(rollback 먼저 완료 → 그 다음 deploy)이
  됐다. 즉 "겹쳤을 때도 안전하다"가 아니라 "이번엔 안 겹쳤다"는 결과 — 진짜
  동시 접근(같은 순간 rmdir/mklink 경합)에서도 안전한지는 여전히 미확정.
  재검증하려면 지연을 없애거나 push 쪽도 job으로 걸어 실제 겹침 여부를
  타임스탬프로 확인하는 개선이 필요.
- [x] **격리망(outbound 차단) 조건에서의 동작 — 실증 완료 (2026-07-10).**
  `netsh advfirewall firewall add rule ... dir=out action=block protocol=any`로
  러너 자체에 실제 OS 레벨 차단을 걸고(`github.com:443` 접속 시도로 차단 확인:
  "An attempt was made to access a socket in a way forbidden by its access
  permissions") 그 상태에서 v1 배포→v2 재배포→빌드실패(무손상)→rollback 전체
  사이클 실행, 전부 PASS. 봉화의 배포 경로는 전부 localhost(Gitea:3000, IIS:80)
  통신만 쓴다는 핵심 주장이 실측으로 확인됨. 차단 해제도 접속 복구로 확인.
  GH Actions 러너 자체의 제어 채널 통신도 안 끊김(job 2m44s 정상 종료, hang 없음).

### 실검증 중 발견한 추가 버그 (전부 fix 커밋으로 반영)
- **`History` 함수명이 PowerShell 내장 별칭(`history`→`Get-History`)과 충돌** —
  모든 실패 경로에서 `Cannot bind parameter 'Count'`로 진짜 에러를 가렸다.
  `Write-BonghwaHistory`로 개명.
- **IIS Application 미등록** — `/app`이 그냥 하위폴더면 ASP.NET이 부모 사이트의
  bin을 찾아 "Could not load type"로 실패. install.ps1이 `New-WebApplication`으로
  LiveJunction을 별도 Application으로 등록하도록 추가.
- **WorkDir/ReleasesDir을 다른 볼륨(D:\)에 두면 IIS AppPool 권한 문제 소지** —
  C:\(IIS 사이트와 같은 볼륨)로 고정.
- **.ps1 파일에 UTF-8 BOM 없으면 Windows PowerShell 5.1이 한글/화살표를 깨뜨림**
  — 전체 .ps1에 BOM 추가.

### 코드 리뷰로 발견 — 아직 실패 재현은 안 됨 (2026-07-11)
- **`rollback.ps1`이 `mklink` 종료 코드를 확인하지 않음.** `deploy.ps1`은
  junction 스위칭 후 `$LASTEXITCODE`를 체크해 실패 시 throw하는데
  (`scripts/deploy.ps1` 4단계), `rollback.ps1`은 같은 자리에서 체크가 없다
  (`scripts/rollback.ps1` 26-27번줄). mklink가 (경합·권한 등으로) 실패해도
  `[rollback] DONE`을 그대로 출력하고 이력에도 ROLLBACK을 정상 기록할 수
  있음 — 실제 junction은 안 바뀌었는데 성공했다고 보고하는 조용한 실패
  가능성. VERIFY 6/6 경합 시나리오에서는 재현되지 않았지만 (실제로는 안
  겹쳐서 mklink 자체가 실패할 기회가 없었음), 코드상 gap은 남아있음. MVP
  스코프 밖 신규 기능이 아니라 기존 rollback 기능의 방어 로직 누락이라
  고쳐도 되는 종류지만, 아직 사용자 확인 전이라 수정하지 않고 기록만 남김.

## 프로토타입 처리
`sim/`은 검증 완료 후에도 **데모/README용으로 유지** (심사위원이 Windows 없이
로직을 1분 안에 재현 가능 — "있어 보이는데 안 도는 것" 방지 무기).

---

# 내러티브 v2 (2026-07-04 크로스체크 반영 — 이후 변경 금지)

## 크로스체크 판정 요약 (5모델, 사회자 팩트체크 후)
- 주장1 "유일한 접근" → 취약. GitLab CE 풀스택을 내부망에 구축하면 runner도
  내부에서 동작 (outbound 불필요). GitHub Actions self-hosted runner만
  github.com outbound 필수라 불가.
- 주장2 "파일 5개 = 결정적 이점" → 취약. 심사는 파일 수가 아니라
  "관리자 권한으로 뭘 하나 + 신뢰 소스냐"를 봄. 커스텀 스크립트가
  커뮤니티 검증된 GitLab CE보다 불리할 수도.
- 주장3 "공백지대" → 붕괴. 반례 실재: Ansible(에이전트리스 WinRM),
  CruiseControl.NET, Jenkins+MSBuild 플러그인.
- 주장4 "Jenkins 불가" → 취약. .hpi 수동 업로드로 오프라인 설치 가능.

## 살아남은 코어 (README·발표의 유일한 주장)
"완전격리망 Windows 단일 서버에서, **신규 반입물 0**(이미 반입된
Git for Windows + Gitea + MSBuild만 사용), **에이전트 0**, **신규 런타임 0**으로
push-to-deploy·이력·롤백을 구현하는 **가장 마찰 낮은 조합**."
- "유일" 아님. "이 제약 교집합에서 반입·운영 마찰 최소" — 이것만 주장.

## 정직한 비교표 (README용 — 반례를 숨기지 않고 선제 배치)
| 대안 | 폐쇄망 동작 | 대신 치르는 비용 |
|---|---|---|
| GitHub Actions self-hosted | ✗ | runner가 github.com outbound 443 필수 |
| GitLab CE + runner 내부 구축 | ○ | 신규 서버·리눅스 스택 반입 심사, 전담 운영 |
| Jenkins (.hpi 오프라인 설치) | ○ | 플러그인 의존성 체인 수동 해소, 업그레이드마다 반복 |
| Ansible (에이전트리스) | ○ | 리눅스 컨트롤 노드 + Python + WinRM 구성 반입 |
| CruiseControl.NET | △ | 사실상 개발 중단된 레거시 |
| 수작업 USB 배포 (현실 다수) | ○ | 인적 오류, 이력 없음, 롤백 = 재작업 |
| **봉화(Bonghwa)** | ○ | **기존 반입물 외 추가 0. 파일 5개.** |

## 발표 방어 라인
- "Jenkins 쓰면 되잖아" → "됩니다. 대신 .hpi 의존성 수동 해소를 업그레이드마다
  반복하셔야 합니다. 봉화(Bonghwa)은 그 운영 마찰 자체를 없앤 선택지입니다."
- "GitLab CE 있잖아" → "됩니다. 신규 리눅스 서버 반입 심사와 전담 운영이
  가능한 조직이라면요. 협력사 1인 담당 환경이 타깃입니다."
- 자기모순 제거: "runner 불가"라고 말하지 말 것. "GitHub Actions runner만
  불가, 나머지는 가능하지만 비용" 구도로만 말할 것.
