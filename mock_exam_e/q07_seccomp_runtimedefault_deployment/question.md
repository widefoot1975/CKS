# q07 — Run a Deployment with the RuntimeDefault seccomp profile

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q07_seccomp_runtimedefault_deployment
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `fin` 에 Deployment `ledger`(replicas 1)가 있고, 컨테이너는 `app`(nginx)과 `helper`(busybox) 두 개다.
Pod 수준 seccomp 설정은 없고, `helper` 컨테이너에는 `seccompProfile.type: Unconfined` 가 들어 있다.

## Task

All containers of Deployment `ledger` in namespace `fin` must run with the container
runtime's default seccomp profile.

1. Set the seccomp profile type `RuntimeDefault` once, at Pod level, in the Pod template of
   Deployment `ledger`. No container may override it with a different profile.
2. After the rollout, run `grep Seccomp: /proc/1/status` in container `app` and then in
   container `helper` of the new Pod, and write both output lines, in this order, to
   `/opt/course/e07/seccomp.txt`.

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

[↑ 문항 목록](../README.md) · [← q06](../q06_networkpolicy_block_apiserver_egress/question.md) · [q08 →](../q08_remove_package_and_user_host/question.md)
