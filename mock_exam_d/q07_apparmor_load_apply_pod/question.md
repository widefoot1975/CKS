# q07 — Load an AppArmor profile and apply it to a Pod

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | System Hardening (10%) |
| Points | 5 |
| Host | `ssh cks-c1` |
| Target time | 5 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q07_apparmor_load_apply_pod
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 워커 노드 `cks-c1-w1` 의 `/etc/apparmor.d/d07-deny-write` 에 AppArmor 프로필 파일이 있지만 **커널에 로드되어 있지 않다**.
namespace `amber` 는 비어 있다. 워커 노드의 AppArmor 가 켜져 있어야 한다(Ubuntu 기본값).

## Task

An AppArmor profile file was placed on worker node `cks-c1-w1` at
`/etc/apparmor.d/d07-deny-write`. It is not loaded yet.

1. On worker node `cks-c1-w1`, load the profile into the kernel in enforce mode and confirm
   with `aa-status` that it is loaded.
2. Create a Pod `writer` in namespace `amber` with image `busybox:1.36` and command
   `sleep 3600` that runs on node `cks-c1-w1`. Its container must use that AppArmor profile
   through the `securityContext` field (not the deprecated annotation).
3. Run `kubectl -n amber exec writer -- touch /tmp/test` and write its complete output
   (stdout and stderr) to `/opt/course/d07/touch.txt` on `cks-c1`.

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

[↑ 문항 목록](../README.md) · [← q06](../q06_anonymous_rbac_binding_remove/question.md) · [q08 →](../q08_disable_listening_service_worker/question.md)
