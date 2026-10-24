# q07 — Confine a Deployment with a Localhost AppArmor profile

| Item | Value |
|---|---|
| Exam | mock_exam_a |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_a/q07_apparmor_profile_deployment
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 `cks-c1-w1` 에는 프로필 파일 `/etc/apparmor.d/cks-a07-deny-write` 가 있지만 커널에 로드되어 있지 않다(워커에서 AppArmor 가 켜져 있어야 한다).
namespace `tide` 의 Deployment `tide-writer`(컨테이너 `writer`, busybox)는 5초마다 `/tmp/heartbeat` 에 쓰고 있고, Pod 템플릿에는 옛 방식의 AppArmor 어노테이션(`unconfined`)이 붙어 있다.

## Task

Deployment `tide-writer` in namespace `tide` must not be able to write anywhere in its
filesystem.

1. On worker node `cks-c1-w1`, load the AppArmor profile defined in
   `/etc/apparmor.d/cks-a07-deny-write` in enforce mode and confirm it is loaded.
2. Change Deployment `tide-writer` so that its Pods always run on node `cks-c1-w1`, and its
   container `writer` runs with that profile. Use the `securityContext` field, not the
   deprecated annotation, and remove the deprecated AppArmor annotation from the Pod template.
3. Write the output of `cat /proc/1/attr/current` executed in the container to
   `/opt/course/a07/attr.txt`.
4. Write the output (stdout and stderr) of `touch /tmp/a07` executed in the container to
   `/opt/course/a07/write-test.txt`. It must fail.

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

[↑ 문항 목록](../README.md) · [← q06](../q06_noderestriction_admission/question.md) · [q08 →](../q08_host_listening_service_disable/question.md)
