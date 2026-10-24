# q17 — Find the container running as root with crictl

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Monitoring, Logging and Runtime Security (20%) |
| Points | 6 |
| Host | `ssh cks-c1` |
| Target time | 8 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q17_crictl_find_root_container
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `stack` 에 Deployment 세 개(`web`, `cache`, `reports`, 각 replicas 1)가 있고 모든 파드가 워커 노드 `cks-c1-w1` 에서 돈다.
이 중 하나의 컨테이너만 UID `0`(root)으로 실행된다. 워커에서 `crictl` 을 쓸 수 있다.

## Task

Exactly one container in namespace `stack` runs as root. Find it from the container runtime
on worker node `cks-c1-w1`.

1. On `cks-c1-w1`, use `crictl` to list the containers of namespace `stack` and determine
   which one runs its main process as UID `0`.
2. Write the name of the Pod of that container to `/opt/course/e17/pod.txt` and the
   container ID (as shown by `crictl ps`, 13 characters) to `/opt/course/e17/container.txt`,
   both on `cks-c1`.
3. Scale the Deployment that owns this Pod to `0` replicas. Do not change the other
   Deployments.

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

[↑ 문항 목록](../README.md) · [← q16](../q16_audit_log_who_deleted/question.md)
