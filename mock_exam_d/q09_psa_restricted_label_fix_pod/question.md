# q09 — Enforce Pod Security restricted and fix a Pod

| Item | Value |
|---|---|
| Exam | mock_exam_d |
| Domain | Minimize Microservice Vulnerabilities (20%) |
| Points | 7 |
| Host | `ssh cks-c1` |
| Target time | 7 min |

## Setup — 사전 환경 설정

문제를 풀기 전에 `cks-c1` 에서 아래 스크립트로 환경을 만든다. 스크립트는 root 로 실행하고, 여러 번 실행해도 안전하다.

**실행** · 스크립트: **[setup.sh](setup.sh)** / **[cleanup.sh](cleanup.sh)**

<details><summary>노드에 저장소가 없을 때 — 스크립트 두 개 내려받기</summary>

```bash
B=https://raw.githubusercontent.com/widefoot1975/CKS/main/mock_exam_d/q09_psa_restricted_label_fix_pod
curl -fsSLO $B/setup.sh && curl -fsSLO $B/cleanup.sh
```

</details>

```bash
sudo bash setup.sh      # 환경 만들기
sudo bash cleanup.sh    # 실습 후 정리
```

설정 직후 namespace `coral` 에는 Pod Security 라벨이 없고, `/opt/course/d09/api.yaml` 로 만든 Pod `api`(`nginxinc/nginx-unprivileged:1.27-alpine`, 포트 8080)가 `Running` 이다.
이 Pod 에는 `securityContext` 가 전혀 없다.

## Task

Namespace `coral` must enforce the Pod Security Standard `restricted`. Pod `api` in this
namespace was created from `/opt/course/d09/api.yaml`.

1. Label namespace `coral` so that Pod Security Admission enforces level `restricted`, pinned
   to version `v1.35`. Write the complete output of your `kubectl label` command (stdout and
   stderr) to `/opt/course/d09/label.txt`.
2. Edit `/opt/course/d09/api.yaml` so that Pod `api` complies with `restricted`: run as
   non-root with UID `101`, use the seccomp profile `RuntimeDefault` (set both in the Pod's
   `securityContext`), disallow privilege escalation and drop all capabilities.
3. Recreate Pod `api` from the edited file. It must be `Running` and Ready in namespace `coral`.

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

[↑ 문항 목록](../README.md) · [← q08](../q08_disable_listening_service_worker/question.md) · [q10 →](../q10_secret_volume_readonly/question.md)
