#!/bin/bash
# PROTOTYPE — 봉화(Bonghwa) rollback (Linux simulation)
# 마지막 DEPLOY 이전 릴리즈로 symlink 복귀. 인자로 릴리즈 디렉토리 지정도 가능.

set -euo pipefail

BONGHWA_HOME="${BONGHWA_HOME:?}"
LIVE_LINK="$BONGHWA_HOME/sim-env/wwwroot/app"
HISTORY="$BONGHWA_HOME/sim-env/history.log"

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
    # 이력에서 현재 live 제외 직전 DEPLOY 릴리즈 찾기
    CURRENT=$(readlink "$LIVE_LINK")
    TARGET=$(grep '|DEPLOY|' "$HISTORY" | awk -F'|' -v cur="$CURRENT" '$4 != cur {last=$4} END {print last}')
fi

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
    echo "[rollback] FAIL: no previous release found (target='$TARGET')" >&2
    exit 1
fi

ln -sfn "$TARGET" "$LIVE_LINK"
echo "$(date -Iseconds)|ROLLBACK|-|$TARGET" >> "$HISTORY"
echo "[rollback] DONE. live -> $(readlink "$LIVE_LINK")"
