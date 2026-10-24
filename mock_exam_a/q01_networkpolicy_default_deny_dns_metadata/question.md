# q01 — Default-deny a namespace and open only DNS, API and external egress

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q01_networkpolicy_default_deny_dns_metadata
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `aurora` 에는 Deployment `api`(http-echo, 컨테이너 포트 `8080`)와 Service `api`(포트 `80` → `8080`), Deployment `frontend`(`app=frontend`, curl 이미지), Pod `batch`(`app=batch`, curl 이미지)가 있다. NetworkPolicy 는 하나도 없어서 모든 통신이 열려 있다.
CNI 는 Cilium 이고 외부(인터넷) 확인에는 노드의 인터넷 연결이 필요하다.

## Task

Namespace `aurora` currently allows all traffic. Lock it down with NetworkPolicies only.
Do not modify the existing Deployments, Pods or Services.

1. Create a NetworkPolicy `default-deny` that denies all ingress and all egress traffic for
   every Pod in `aurora`.
2. Create a NetworkPolicy `allow-dns` that allows every Pod in `aurora` to send DNS queries
   (UDP and TCP port `53`) only to the Pods labeled `k8s-app=kube-dns` in namespace
   `kube-system`.
3. Create a NetworkPolicy `api-ingress` that allows traffic to Pods `app=api` only from Pods
   `app=frontend` of the same namespace, only on the port the `api` container listens on.
   Create a NetworkPolicy `frontend-egress` that allows Pods `app=frontend` to reach Pods
   `app=api` on that same port.
4. Create a NetworkPolicy `external-egress` that allows every Pod in `aurora` egress to any
   IP address outside the cluster, except the cloud metadata address `169.254.169.254`.
5. From a `frontend` Pod run `curl -s -m 3 http://api` and write its output to
   `/opt/course/a01/frontend-api.txt`. The same request from Pod `batch` must time out.

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

[↑ 문항 목록](../README.md) · [q02 →](../q02_cis_kube_bench_apiserver_kubelet/question.md)
