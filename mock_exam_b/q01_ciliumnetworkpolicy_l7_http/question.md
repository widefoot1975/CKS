# q01 — L7 HTTP policy with CiliumNetworkPolicy

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q01_ciliumnetworkpolicy_l7_http
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `orion` 에는 Deployment `backend`(라벨 `app=backend`, `hashicorp/http-echo` 가 8080 에서 어떤 메서드·경로든 `backend` 로 응답)와 Service `backend:8080`, Pod `client`(라벨 `role=client`)와 Pod `intruder`(라벨 `role=guest`)가 있다.
NetworkPolicy 와 CiliumNetworkPolicy 는 하나도 없어서 지금은 두 Pod 모두 어떤 요청이든 `200` 을 받는다. CNI 는 Cilium(L7 정책용 Envoy 포함)이어야 한다.

## Task

Namespace `orion` runs Deployment `backend` (label `app=backend`, HTTP on port `8080`, exposed by
Service `backend`) and two Pods: `client` (label `role=client`) and `intruder` (label `role=guest`).
The CNI is Cilium. Do not change the existing workloads or Services.

1. Create a Kubernetes NetworkPolicy named `default-deny-ingress` in namespace `orion` that denies
   all ingress traffic to every Pod in the namespace.
2. Create a CiliumNetworkPolicy named `backend-l7` in namespace `orion` that selects the Pods with
   label `app=backend` and allows ingress only from Pods with label `role=client` to TCP port
   `8080`, and only for HTTP `GET` requests whose path starts with `/api/v1/`.
3. Send the following requests to `http://backend:8080` with a timeout of 3 seconds and write one
   line per request in the form `<pod> <method> <path> <http_code>` to
   `/opt/course/b01/result.txt`, in this order. Use `000` when no HTTP response is received.
   - from `client`: `GET /api/v1/items`
   - from `client`: `POST /api/v1/items`
   - from `client`: `GET /admin`
   - from `intruder`: `GET /api/v1/items`

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

[↑ 문항 목록](../README.md) · [q02 →](../q02_cis_etcd_kubelet_file_permissions/question.md)
