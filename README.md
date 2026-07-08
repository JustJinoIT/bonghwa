# 봉화 (Bonghwa)

> 완전격리망 윈도우 서버를 위한 git-push 자동배포.
> **신규 반입물 0 · 에이전트 0 · 핵심 파일 6개.**
>
> 조선의 봉수(烽燧)는 외부 연결 없이 신호 하나를 국경에서 도성까지 전달했다.
> 봉화는 완전격리망에서 push 하나를 배포까지 전달한다.

<!-- TODO: 데모 GIF (Windows 실검증 후) -->

## 문제

outbound 443까지 차단된 완전격리망(air-gapped)의 Windows Server + .NET Framework
+ IIS 환경. 국내 금융·반도체·방산 SI 현장의 기본값이다. 이 환경의 배포 현실:

- GitHub Actions self-hosted runner → github.com outbound 필수. **동작 불가.**
- GitLab CE 내부 구축 → 가능하다. 신규 리눅스 서버 반입 심사와 전담 운영 인력이
  있다면. 협력사 1인 담당에게는 없다.
- Jenkins → .hpi 수동 업로드로 오프라인 설치는 된다. 플러그인 의존성 체인을
  업그레이드마다 손으로 푸는 비용을 감수한다면.
- 그래서 현실의 다수는 **수작업 USB 배포**다. 이력 없음, 롤백 = 재작업, 인적 오류.

봉화(Bonghwa)은 "유일한 해법"이 아니다. **이미 반입돼 있는 것(Git for Windows,
Gitea, MSBuild)만으로, 추가 반입 심사 없이** push-to-deploy·이력·롤백을 얻는
가장 마찰 낮은 조합이다.

## 대안 비교 — 정직하게

| 대안 | 격리망 동작 | 치르는 비용 |
|---|---|---|
| GitHub Actions self-hosted | ✗ | runner가 github.com outbound 443 필수 |
| GitLab CE + runner 내부 구축 | ○ | 신규 서버·리눅스 스택 반입 심사, 전담 운영 |
| Jenkins (.hpi 오프라인 설치) | ○ | 플러그인 의존성 수동 해소, 업그레이드마다 반복 |
| Ansible (에이전트리스 WinRM) | ○ | 리눅스 컨트롤 노드 + Python 반입·구성 |
| CruiseControl.NET | △ | 사실상 개발 중단 |
| 수작업 USB 배포 | ○ | 인적 오류, 이력 없음, 롤백 = 재작업 |
| **봉화(Bonghwa)** | **○** | **기존 반입물 외 추가 0** |

## 동작

```
git push → Gitea post-receive hook → MSBuild → 릴리즈 폴더 스테이징
        → IIS junction 원자적 스위칭 → 이력 기록
롤백 = 이전 릴리즈 폴더로 junction 재연결 (재빌드 불필요, 수 초)
```

핵심 파일 6개가 전부다:
- `hooks/post-receive` — push 감지 (sh → PowerShell 위임)
- `scripts/bonghwa.config.ps1` — 모든 경로·설정 단일 지점
- `scripts/deploy.ps1` — checkout → MSBuild → junction 스위칭 → 이력
- `scripts/rollback.ps1` — 이력 기반 복귀
- `scripts/bonghwa.ps1` — status/history/deploy/rollback 단일 진입점 CLI
- `scripts/install.ps1` — 사전점검(MSBuild/git/sh.exe/IIS) + 디렉토리 준비 + hook 설치
- (선택) `sim/` — Windows 없이 로직을 재현하는 시뮬레이션 (빌드 실패 경로 포함)

## 5분 재현 (Windows 불필요)

```bash
bash sim/run_sim.sh
```
push → 배포 → 재push → 롤백 전체 사이클이 mock MSBuild/IIS로 실행되고
마지막에 PASS/FAIL을 판정한다. 심사·검토자용.

## 설치 (Windows Server)

<!-- TODO: Windows 실검증 후 확정 -->
1. `scripts/bonghwa.config.ps1` 경로 수정
2. `scripts/install.ps1 -GiteaRepoPath <bare repo 경로>` 실행 — 사전점검 + 디렉토리 준비 + hook 설치를 한 번에
3. push

## 설계 원칙

- **반입 심사 친화**: 전체 코드가 짧은 텍스트 파일 — 보안 담당자가 전부 읽고
  승인할 수 있는 분량. 블랙박스 에이전트·바이너리 없음.
- **격리망-first**: 인터넷 연결을 전제한 도구를 격리망용으로 개조한 게 아니라,
  외부 연결 0을 시작점으로 설계.
- **의도된 최소주의**: 멀티서버·대시보드·알림 없음. 단일 서버 협력사 환경이라는
  한 문제만 확실히 푼다.

## License

MIT
