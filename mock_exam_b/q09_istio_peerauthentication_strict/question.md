# q09 — Enforce Istio mTLS with PeerAuthentication STRICT

| Item | Value |
|---|---|
| Exam | mock_exam_b |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_b/q09_istio_peerauthentication_strict
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 Istio(istiod, 프로필 `minimal`)가 설치돼 있고, namespace `bank` 에 Deployment `ledger`(nginx, Service `ledger:80`)와 Deployment `teller`(curl 클라이언트)가, namespace `outside` 에 Deployment `stranger`(curl 클라이언트)가 있다. 아직 어느 namespace 에도 사이드카 주입이 켜져 있지 않아 모든 Pod 가 `1/1` 이고, `stranger` 도 `ledger` 에 평문 HTTP 로 접속된다.
istioctl 1.26.2 와 Istio 가 없으면 setup 이 설치하므로 인터넷이 필요하다(Istio 는 cleanup 이 지우지 않는다). Cilium 이 kube-proxy 대체 모드라면 사이드카 리다이렉트를 위해 `socketLB.hostNamespaceOnly=true`(cilium-config `bpf-lb-sock-hostns-only: "true"`)가 필요하며 setup 이 아니면 경고를 출력한다.

## Task

Istio is installed in the cluster. Traffic to the workloads in namespace `bank` must be mutually
authenticated and encrypted.

1. Enable automatic Istio sidecar injection for namespace `bank` and make sure that every Pod of
   the Deployments `ledger` and `teller` runs with an `istio-proxy` sidecar. Do not enable
   injection for namespace `outside`.
2. Create a PeerAuthentication named `default` in namespace `bank` that enforces mutual TLS in
   `STRICT` mode for all workloads in the namespace.
3. Request `http://ledger.bank.svc.cluster.local` with a timeout of 3 seconds from a Pod of
   `teller` and from a Pod of `stranger`, and write two lines `teller <http_code>` and
   `stranger <http_code>` to `/opt/course/b09/result.txt`. Use `000` when no HTTP response is
   received. `teller` must get `200`, `stranger` must not.

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

[↑ 문항 목록](../README.md) · [← q08](../q08_host_users_groups_sshd/question.md) · [q10 →](../q10_secret_file_mount_resource_names/question.md)
