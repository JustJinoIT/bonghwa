# Contributing

봉화(Bonghwa)는 완전격리망 Windows 서버를 위한 최소주의 배포 도구다.
기여하기 전에 아래를 먼저 읽을 것.

## 스코프는 고정돼 있다

MVP 범위는 **push 감지 → MSBuild → IIS junction 배포 → 이력 → 롤백**, 이
5개뿐이다. 2026-07-08부로 기능 추가는 종료됐다. SBOM, RBAC, 대시보드, 알림,
멀티서버 등 "있으면 좋을 것 같은" 개선 요청은 이 저장소의 목표와 맞지 않아
받지 않는다. 버그 수정과 기존 5개 기능의 견고성 검증(edge case 재현, CI 검증
추가)은 언제나 환영이다.

## 커밋 전 필수

```bash
bash sim/run_sim.sh
```
push→build→deploy→이력→rollback→빌드실패(무손상) 전체 사이클을 Windows 없이
mock으로 재현하는 게이트다. `PASS`가 실제로 출력되는 것을 확인하기 전에는
커밋하지 않는다.

시크릿 하드코딩 여부도 커밋 전에 확인한다:
```bash
git diff --cached | grep -iE "sk-ant-|sbp_|AIzaSy|gsk_|password|secret|token"
```
1줄이라도 걸리면 커밋을 중단하고 원인을 먼저 해결한다.

## Windows 실검증

로컬에 Windows 서버가 없다면 `.github/workflows/verify-windows.yml`이
GitHub Actions `windows-2022` 러너에서 실제 MSBuild+IIS+Gitea 전체 사이클을
검증한다. `main`에 push하면 자동으로 돈다. 결과와 발견 사항은 `NOTES.md`에
날짜와 함께 기록한다 — "됐을 것이다" 가정이 아니라 실제로 확인된 것만.

## 커밋 스타일

`fix:`/`feat:`/`docs:`/`ci:` 접두사 + "무엇을(+왜)" 짧게. 커밋 하나는 논리적으로
한 가지 일만 한다. 커밋 date 조작 금지(`--date`, `GIT_AUTHOR_DATE` 등 미사용).

## 워크플로우

이 저장소는 지금 단일 관리자가 검증 후 `main`에 직접 push하는 방식으로
운영된다. `main`은 force-push와 브랜치 삭제만 막혀 있고(실수 방지), PR이나
CI 통과를 병합 조건으로 강제하진 않는다 — CI가 push *이후에* 도는 구조라서다.
외부 기여를 낼 때는 이 사실을 참고해 별도 브랜치에서 작업 후 PR로 올려줄 것
(관리자가 직접 push하는 것과는 별개로, 리뷰가 필요한 변경이라는 뜻).

## 원본 취급

회사/타 사내 도구의 코드를 복붙하지 않는다. 참고할 것은 개념(훅 위임 방식,
junction 스위칭 아이디어)뿐이며 코드는 항상 신규 작성한다.
