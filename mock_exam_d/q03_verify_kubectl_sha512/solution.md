# q03 — Verify a kubectl binary against its official SHA-512 · 풀이

← 문제: **[question.md](question.md)**

## 문제 (해석)

**원문**

> A colleague handed over the binary `/opt/course/d03/kubectl` and claims it is the official
> `linux/amd64` kubectl of the same version as this cluster's API server.
>
> 1. Download the official SHA-512 checksum for that kubectl version from `dl.k8s.io` and save it
>    to `/opt/course/d03/kubectl.sha512`.
> 2. Compare it with the checksum of `/opt/course/d03/kubectl`. Write exactly `MATCH` or
>    `MISMATCH` to `/opt/course/d03/result.txt`.
> 3. If the result is `MISMATCH`, delete `/opt/course/d03/kubectl`.

**해석**

동료가 `/opt/course/d03/kubectl` 바이너리를 건네면서, 이 클러스터의 API 서버와 같은 버전의 공식 `linux/amd64` kubectl 이라고 한다.

1. 그 버전의 공식 SHA-512 체크섬을 `dl.k8s.io` 에서 받아 `/opt/course/d03/kubectl.sha512` 에 저장한다.
2. `/opt/course/d03/kubectl` 의 체크섬과 비교해 `/opt/course/d03/result.txt` 에 정확히 `MATCH` 또는 `MISMATCH` 를 쓴다.
3. 결과가 `MISMATCH` 이면 `/opt/course/d03/kubectl` 을 삭제한다.

## 모범 풀이

**1) 버전 확인과 공식 체크섬 받기**

```bash
kubectl version                                  # Server Version: v1.35.x  ← 기준은 클러스터(서버) 버전
/opt/course/d03/kubectl version --client         # 바이너리가 주장하는 버전 (변조돼도 문자열은 그대로일 수 있다)
V=$(kubectl get --raw /version | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p')   # 서버 버전만 나오는 엔드포인트
echo $V                                          # v1.35.x
curl -fsSL -o /opt/course/d03/kubectl.sha512 https://dl.k8s.io/release/$V/bin/linux/amd64/kubectl.sha512
cat /opt/course/d03/kubectl.sha512               # 128자리 16진수 한 줄 (파일명 없음)
```

URL 형식은 `https://dl.k8s.io/release/<버전>/bin/<os>/<arch>/<바이너리>` 이고 체크섬은 같은 경로에 `.sha256`, `.sha512`
를 붙이면 됩니다. kubectl 설치 문서(kubernetes.io)에 그대로 나오는 형식이라 시험 중에도 찾을 수 있습니다.
`jq` 가 있으면 `kubectl version -o json | jq -r .serverVersion.gitVersion` 이 더 간단합니다.

**2) 비교**

```bash
cd /opt/course/d03
sha512sum kubectl | awk '{print $1}'             # 로컬 해시
cat kubectl.sha512                               # 공식 해시
echo "$(cat kubectl.sha512)  kubectl" | sha512sum --check
# kubectl: FAILED
# sha512sum: WARNING: 1 computed checksum did NOT match
```

```bash
if echo "$(cat kubectl.sha512)  kubectl" | sha512sum --check --status; then echo MATCH; else echo MISMATCH; fi > result.txt
cat result.txt                                    # MISMATCH
```

`sha512sum --check` 형식은 `<해시><공백 두 칸><파일명>` 입니다. 공식 `.sha512` 파일에는 파일명이 없으므로 직접 붙입니다.
눈으로 비교할 때는 앞뒤 몇 글자만 보지 말고 `diff <(sha512sum kubectl | cut -d' ' -f1) kubectl.sha512` 처럼 기계로 비교합니다.

**3) 불일치면 삭제**

```bash
rm -f /opt/course/d03/kubectl
```

변조된 바이너리는 실행조차 하지 않는 것이 원칙입니다. 1단계에서 `--client` 로 버전을 본 것도 엄밀히는 위험한 행동이라,
버전은 **클러스터 쪽**(`kubectl version` 의 Server Version)에서 얻는 습관을 들입니다.

## 검증

```bash
ls -l /opt/course/d03/                       # kubectl.sha512, result.txt 만 남음
wc -c /opt/course/d03/kubectl.sha512         # 128 (+ 개행)
cat /opt/course/d03/result.txt               # MISMATCH
```

## 오답 원인 / 배운 점

- **왜 틀렸나**:
- **기억할 것**: `curl -LO https://dl.k8s.io/release/<v>/bin/linux/amd64/kubectl.sha512` → `echo "$(cat kubectl.sha512)  kubectl" | sha512sum --check`.
- **헷갈리는 지점**: 버전이 다르면 진짜 바이너리여도 MISMATCH 가 나므로 버전을 먼저 맞춥니다. `sha256sum` 과 `sha512sum` 을 섞지 않습니다. 컨테이너 이미지로 도는 컴포넌트(kube-apiserver 등)는 바이너리 대신 `crictl images --digests` 의 이미지 digest 로 비교합니다.

## 참고 문서

- 검색어: `install kubectl linux`, `validate the binary`
- https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

---

[↑ 문항 목록](../README.md) · [← 문제로](question.md) · [다음 문제 q04 →](../q04_role_rolebinding_sa_least_privilege/question.md)
