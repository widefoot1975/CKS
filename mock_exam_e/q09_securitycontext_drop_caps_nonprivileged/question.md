# q09 — Drop capabilities from a privileged container

| Item | Value |
|---|---|
| Exam | mock_exam_e |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_e/q09_securitycontext_drop_caps_nonprivileged
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `edge` 에 Deployment `netmon`(busybox, root 로 실행)이 있고, 컨테이너가 `privileged: true` 에 capability `NET_ADMIN`·`SYS_ADMIN` 을 추가로 받고 있다.
지금은 컨테이너 안에서 `ip link set lo mtu 65536` 같은 네트워크 설정 변경이 성공한다(NET_ADMIN).

## Task

Container `netmon` of Deployment `netmon` in namespace `edge` only needs raw sockets.

1. Change the container so that it is not privileged and cannot gain more privileges than
   its parent process (`allowPrivilegeEscalation`).
2. Drop all Linux capabilities from the container and add back only `NET_RAW`.
3. After the rollout, write the output of `grep CapEff /proc/1/status` from the new Pod to
   `/opt/course/e09/capeff.txt`.

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

[↑ 문항 목록](../README.md) · [← q08](../q08_remove_package_and_user_host/question.md) · [q10 →](../q10_encryption_config_identity_to_aescbc/question.md)
