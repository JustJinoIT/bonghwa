#!/bin/bash
# PROTOTYPE — 한 명령 실행: bash sim/run_sim.sh
# 검증 질문: "push → hook → build → deploy → history → rollback 사이클이 도는가"

set -euo pipefail

export BONGHWA_HOME="$(cd "$(dirname "$0")/.." && pwd)"
ENV="$BONGHWA_HOME/sim-env"

echo "=== [setup] 초기화 (PROTOTYPE — wipe me) ==="
rm -rf "$ENV"
mkdir -p "$ENV"/{repo.git,work,releases,wwwroot,dev-clone}

git init --bare -b master "$ENV/repo.git" -q
cp "$BONGHWA_HOME/sim/post-receive" "$ENV/repo.git/hooks/post-receive"
chmod +x "$ENV/repo.git/hooks/post-receive" "$BONGHWA_HOME"/sim/*.sh

# 개발자 클론 (가짜 .NET 프로젝트)
git init -b master "$ENV/dev-clone" -q
cd "$ENV/dev-clone"
git config user.email dev@sim.local && git config user.name dev
git remote add origin "$ENV/repo.git"

echo "=== [1] 첫 push → 자동 배포 확인 ==="
cat > Program.cs <<'EOF'
// v1
class Program { static void Main() { System.Console.WriteLine("v1"); } }
EOF
git add . && git commit -m "v1" -q
git push origin master 2>&1 | grep -E '^remote:|bonghwa|deploy' || true

V1=$(cat "$ENV/wwwroot/app/Program.cs" | head -1)
echo ">>> live 내용: $V1"

echo ""
echo "=== [2] 두번째 push → 배포 갱신 확인 ==="
sleep 1  # 릴리즈 타임스탬프 구분
sed -i.bak 's/v1/v2/g' Program.cs && rm -f Program.cs.bak
git add . && git commit -m "v2" -q
git push origin master 2>&1 | grep -E '^remote:' || true

V2=$(cat "$ENV/wwwroot/app/Program.cs" | head -1)
echo ">>> live 내용: $V2"

echo ""
echo "=== [3] 롤백 → v1 복귀 확인 ==="
bash "$BONGHWA_HOME/sim/rollback.sh"
V3=$(cat "$ENV/wwwroot/app/Program.cs" | head -1)
echo ">>> live 내용: $V3"

echo ""
echo "=== [4] 배포 이력 ==="
cat "$ENV/history.log"

echo ""
echo "=== 판정 ==="
[ "$V1" = "// v1" ] && [ "$V2" = "// v2" ] && [ "$V3" = "// v1" ] \
  && echo "PASS: push감지→build→deploy→이력→rollback 전체 사이클 동작" \
  || { echo "FAIL: v1='$V1' v2='$V2' v3='$V3'"; exit 1; }
