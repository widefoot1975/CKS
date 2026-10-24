#!/usr/bin/env bash
# d02 — Fix the kube-bench profiling finding on the API server · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전, 인터넷 필요: kube-bench 설치)
set -euo pipefail

[ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ] || export KUBECONFIG=/etc/kubernetes/admin.conf

M=/etc/kubernetes/manifests/kube-apiserver.yaml
D=/opt/course/d02
KB_VER=0.10.4

wait_api() {
  sleep 10
  until kubectl get --raw=/readyz >/dev/null 2>&1; do sleep 3; done
}

# 0) 이전 실습 흔적 정리: 백업이 있으면 원본 매니페스트를 먼저 되돌린다
if [ -f "$D/backup/kube-apiserver.yaml" ]; then
  cp "$D/backup/kube-apiserver.yaml" "$M"
  echo "이전 실습의 매니페스트를 복원했다. API 서버 재시작 대기..."
  wait_api
fi
rm -rf "$D"
mkdir -p "$D/backup"

# 1) kube-bench 가 없으면 고정 버전으로 설치 (바이너리 + cfg 디렉터리)
if ! command -v kube-bench >/dev/null 2>&1 || [ ! -d /etc/kube-bench/cfg ]; then
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/kb.tgz" \
    "https://github.com/aquasecurity/kube-bench/releases/download/v${KB_VER}/kube-bench_${KB_VER}_linux_amd64.tar.gz"
  tar -xzf "$tmp/kb.tgz" -C "$tmp"
  install -m 0755 "$tmp/kube-bench" /usr/local/bin/kube-bench
  mkdir -p /etc/kube-bench
  rm -rf /etc/kube-bench/cfg
  cp -r "$tmp/cfg" /etc/kube-bench/cfg
  rm -rf "$tmp"
fi
kube-bench version || true

# 2) 원본 백업 (manifests 디렉터리 밖)
cp "$M" "$D/backup/kube-apiserver.yaml"

# 3) 고장 내기: --profiling=true 를 명시한다 (기존 --profiling 줄은 지우고 kube-apiserver 바로 아래에 추가)
sed -i '/- --profiling=/d' "$M"
sed -i 's/^\(\s*\)- kube-apiserver$/&\n\1- --profiling=true/' "$M"
grep -q -- '- --profiling=true' "$M" || { echo "매니페스트 수정 실패"; exit 1; }

# 4) API 서버가 새 플래그로 다시 뜰 때까지 대기
echo "kube-apiserver 재시작 대기..."
wait_api

# 5) 시작 상태 확인
ps -ef | grep '[k]ube-apiserver' | tr ' ' '\n' | grep -- '--profiling' || true
kubectl -n kube-system get pod -l component=kube-apiserver
