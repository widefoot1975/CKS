# q11 — Enforce mTLS STRICT with Istio PeerAuthentication

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 6 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q11_istio_peerauthentication_strict_basic
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `mesh-app`(라벨 `istio-injection=enabled`)에 사이드카가 붙은 Deployment·Service `api` 와 파드 `client` 가 있고, namespace `legacy` 에는
사이드카 없는 파드 `client` 가 있다. PeerAuthentication 은 없어서(기본 PERMISSIVE) 두 클라이언트 모두 `http://api.mesh-app` 에 접속된다.
Istio(`istioctl` 1.26.2, profile `minimal`)가 없으면 setup 이 설치하므로 인터넷 연결이 필요하다. Istio 는 공용 구성요소라 `cleanup.sh` 가 지우지 않는다.
Cilium 이 kube-proxy 대체 모드라면 Istio 문서 권장대로 `socketLB.hostNamespaceOnly=true` 가 설정되어 있어야 사이드카가 트래픽을 가로챈다.

## Task

Workloads in namespace `mesh-app` must only accept mutual TLS traffic from the mesh.

1. Create a PeerAuthentication named `default` in namespace `mesh-app` that sets the mTLS
   mode to `STRICT` for all workloads in the namespace.
2. From Pod `client` in namespace `legacy`, run `curl -s -m 5 http://api.mesh-app` and write
   only the curl exit code to `/opt/course/e11/legacy.txt`.
3. From container `client` of Pod `client` in namespace `mesh-app`, run
   `curl -s -m 5 http://api.mesh-app` and write its output to `/opt/course/e11/mesh.txt`.

## My attempt

```bash

```

## Record

<!-- One row per attempt. Score = points earned (0 … Points). The first row is the mock exam itself; later rows are reviews. -->

| Date | Time (min) | Score | Note |
|---|---|---|---|
|  |  |  |  |

---

Solution → **[solution.md](solution.md)**

[↑ 문항 목록](../README.md) · [← q10](../q10_encryption_config_identity_to_aescbc/question.md) · [q12 →](../q12_bom_generate_spdx_sbom/question.md)
