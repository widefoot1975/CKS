# q01 — Default-deny ingress with one allowed client

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q01_networkpolicy_default_deny_ingress
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `ruby` 에 Deployment `web`(nginx, 포트 80)과 Service `web`, 클라이언트 Pod `client`(`role=client`)와 `stranger`(`role=guest`)가 있다.
NetworkPolicy 는 하나도 없어서 두 클라이언트 모두 `web` 에 접속된다. CNI 는 Cilium 이라 NetworkPolicy 가 실제로 적용된다.

## Task

Namespace `ruby` runs Deployment `web` behind Service `web` (port `80`) and two client Pods,
`client` and `stranger`. Currently every Pod can reach `web`.

1. Create a NetworkPolicy `default-deny-ingress` in namespace `ruby` that selects all Pods in
   the namespace and denies all incoming traffic. Outgoing traffic must not be restricted.
2. Create a NetworkPolicy `allow-client-to-web` in namespace `ruby` that allows incoming
   traffic to the Pods with label `app=web` only from Pods with label `role=client` in the same
   namespace, and only on TCP port `80`.
3. From Pod `client` and from Pod `stranger`, run
   `curl -s -m 3 -o /dev/null -w '%{http_code}' http://web` and write the printed value to
   `/opt/course/d01/client.txt` and `/opt/course/d01/stranger.txt` respectively.

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

[↑ 문항 목록](../README.md) · [q02 →](../q02_kube_bench_apiserver_profiling/question.md)
