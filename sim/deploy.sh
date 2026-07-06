#!/bin/bash
# PROTOTYPE — 봉화(Bonghwa) deploy (Linux simulation)
# MSBuild → mock, IIS junction → symlink. 나머지 로직은 실제와 동일.

set -euo pipefail

COMMIT="$1"
BONGHWA_HOME="${BONGHWA_HOME:?}"
REPO_BARE="$BONGHWA_HOME/sim-env/repo.git"
WORK_DIR="$BONGHWA_HOME/sim-env/work"
RELEASES="$BONGHWA_HOME/sim-env/releases"
LIVE_LINK="$BONGHWA_HOME/sim-env/wwwroot/app"   # IIS junction 대응
HISTORY="$BONGHWA_HOME/sim-env/history.log"

STAMP=$(date +%Y%m%d_%H%M%S)
RELEASE_DIR="$RELEASES/${STAMP}_${COMMIT:0:8}"

echo "[deploy] 1/4 checkout $COMMIT"
rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
git --git-dir="$REPO_BARE" --work-tree="$WORK_DIR" checkout -f "$COMMIT" -- . 2>/dev/null \
  || git --git-dir="$REPO_BARE" --work-tree="$WORK_DIR" checkout -f "$COMMIT"

echo "[deploy] 2/4 build (mock MSBuild)"
mkdir -p "$RELEASE_DIR"
# mock: 소스의 *.cs를 "빌드 산출물"로 복사 + 빌드 마커
cp -r "$WORK_DIR/." "$RELEASE_DIR/"
echo "built=$COMMIT at=$STAMP" > "$RELEASE_DIR/BUILD_INFO.txt"

echo "[deploy] 3/4 switch live symlink → $RELEASE_DIR"
mkdir -p "$(dirname "$LIVE_LINK")"
ln -sfn "$RELEASE_DIR" "$LIVE_LINK"

echo "[deploy] 4/4 record history"
echo "$(date -Iseconds)|DEPLOY|$COMMIT|$RELEASE_DIR" >> "$HISTORY"

echo "[deploy] DONE. live -> $(readlink "$LIVE_LINK")"
