#!/usr/bin/env bash
# b03 — Verify platform binaries and the kube-apiserver image · 사전 환경 설정
# 실행: sudo bash setup.sh   (cks-c1 에서 root 로 실행, 여러 번 실행해도 안전)
set -euo pipefail
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

# 0) 이전 실습 흔적 정리
rm -rf /opt/course/b03
mkdir -p /opt/course/b03/bin /opt/course/b03/sha512
D=/opt/course/b03

# 1) 클러스터(apiserver) 버전 확인 → 같은 버전의 공식 바이너리와 .sha512 다운로드
V=$(kubectl get --raw /version | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p')
[ -n "$V" ] || { echo "클러스터 버전을 알 수 없다"; exit 1; }
echo "cluster version: $V"
for b in kubectl kubelet kube-apiserver; do
  curl -fsSLo $D/bin/$b "https://dl.k8s.io/release/$V/bin/linux/amd64/$b"
  curl -fsSLo $D/sha512/$b.sha512 "https://dl.k8s.io/release/$V/bin/linux/amd64/$b.sha512"
done
chmod 755 $D/bin/*

# 2) 변조: kubelet 은 끝에 바이트 추가(크기 변함), kube-apiserver 는 중간 1바이트 덮어쓰기(크기 그대로)
printf 'cks-b03-implant' >> $D/bin/kubelet
for c in X Y; do
  printf '%s' "$c" | dd of=$D/bin/kube-apiserver bs=1 seek=40000 conv=notrunc status=none
  h=$(sha512sum $D/bin/kube-apiserver | cut -d' ' -f1)
  [ "$h" != "$(cat $D/sha512/kube-apiserver.sha512)" ] && break
done

# 3) 시작 상태 확인
ls -l $D/bin $D/sha512
