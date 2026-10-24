# q01 — Allow ingress only from one namespace

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Cluster Setup (15%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q01_networkpolicy_allow_from_namespace
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `orion` 에 Deployment `api`(라벨 `app=api`, 포트 `8080`)와 Service `api` 가 있고, NetworkPolicy 는 하나도 없다.
namespace `watchtower` 와 `guest` 에 각각 curl 파드 `probe` 가 있으며, 지금은 두 파드 모두 `api` 에 접속된다. CNI 는 Cilium 이다.

## Task

The API in namespace `orion` must only be reachable from the watchtower monitoring stack.

1. Create a NetworkPolicy named `api-allow-watchtower` in namespace `orion` that selects the
   Pods with label `app=api` and allows ingress to them **only** from Pods in namespace
   `watchtower`, on TCP port `8080`. Do not change any namespace labels.
2. From Pod `probe` in namespace `watchtower`, run `curl -s -m 3 http://api.orion:8080` and
   write its output to `/opt/course/e01/watchtower.txt`.
3. From Pod `probe` in namespace `guest`, run the same command and write only the curl exit
   code to `/opt/course/e01/guest.txt`.

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

[↑ 문항 목록](../README.md) · [q02 →](../q02_kubelet_anonymous_auth_disable/question.md)
