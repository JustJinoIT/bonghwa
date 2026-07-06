# 봉화(Bonghwa) — 프로젝트 규칙

완전격리망 Windows 서버용 git-push 자동배포. 파일 5개(+sim) 이상 늘리지 않는다.

## MVP 범위 고정 (절대 변경 금지)

push 감지 → MSBuild → IIS junction 배포 → 이력 → 롤백. 이 5개만.

**아래는 어떤 이유로도 추가하지 않는다:**
SBOM, RBAC, 대시보드, 알림(Slack/Telegram 등), 멀티서버, AI/LLM 연동, 그 외
"있으면 좋을 것 같은" 모든 기능. 기능 추가 요청이 오면 이 규칙을 먼저 상기시키고
거절한다.

## 원본 취급

- 회사 Gitea 스크립트 **복붙 금지**. 참고할 것은 개념(훅 위임 방식, junction
  스위칭 아이디어)뿐이며 코드는 항상 신규 작성한다.
- 비밀값(계정/토큰/키) 하드코딩 금지. 현재 MVP는 로컬 파일시스템 작업만 하므로
  **비밀값 자체가 필요 없는 것이 정상 상태**다 — 어딘가에 비밀값이 나타나면
  그 자체가 설계 이탈 신호로 보고 즉시 중단.
- `.gitignore`: `.env*`, `*.key`, `*.pem`, `*.pfx`, `credentials.json`,
  `token.json` 등 표준 패턴 유지. 커밋 전 `git diff --cached | grep -E
  "sk-ant-|sbp_|AIzaSy|gsk_|password|secret|token"` 1줄이라도 걸리면 중단.

## 검증 루프 금지

- **크로스체크는 이미 1회(2026-07-04, 5모델) 소진했다.** 재검증 요청하지 않는다.
- **README 내러티브 v2(NOTES.md 하단, 크로스체크 반영본)는 이후 변경 금지.**
  주장 강도·비교표·방어 라인 문구를 다시 다듬지 않는다. 오탈자·링크 등 순수
  기계적 수정만 허용.

## 커밋 전 필수

```bash
bash sim/run_sim.sh
```
PASS 출력 확인 전에는 어떤 커밋도 만들지 않는다.

## 커밋 스타일

- "what(+why)" 짧게. `feat/fix/docs/security` 접두사.
- 커밋 date 조작 금지 (`--date`, `GIT_AUTHOR_DATE` 등 사용하지 않음).

## 완료 기준

"됐을 것이다" 가정 금지. `sim/run_sim.sh`가 실제로 PASS를 출력하는 것을 눈으로
확인한 뒤에만 완료로 간주한다. Windows 실배포 관련 항목(MSBuild 실빌드, IIS
junction 파일잠금, Gitea 훅 등록 방식)은 NOTES.md의 "남은 실검증"에 남겨두고
여기서 임의로 해결됐다고 쓰지 않는다.
